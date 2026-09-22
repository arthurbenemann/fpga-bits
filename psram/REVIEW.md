# SPI / PSRAM controller review

Reviewed at `1519bec` ("working spi, plus testbench") — `psram/psram.v`,
`psram/bench_iverilog.v`, `psram/Makefile`, `psram/icebreaker.pcf`, against the
[PMOD-PSRAM-SDCARD](https://github.com/arthurbenemann/PMOD-PSRAM-SDCARD) board
(ESP-PSRAM64H, 64 Mbit = **8 MByte**, plus a microSD socket).

Everything below marked **[verified]** was reproduced in simulation. Run it
yourself:

```sh
cd psram/sim && make check     # needs only iverilog
```

`sim/psram_model.v` is a behavioural ESP-PSRAM64H in single-SPI mode that
answers `0x9F` and independently flags tCEM / tCPH violations.

---

## Verdict

The controller is **correct**, and the simulation confirms it: driven against a
behavioural PSRAM it reads back

```
zzzzzzzz 0d5d deadbeef1234
         ^^^^ MFID=0x0D (AP Memory), KGD=0x5D
```

which is the right answer for this part. The `z` nibbles are the first 32 bit
times (command + address), where the PSRAM isn't driving SO yet — expect
garbage there on hardware, not zeroes.

Several things are genuinely well done: `clkdiv2` is used as a **clock enable**
rather than as a divided clock, so there's one clock domain and no gated clock;
SCLK comes out of a register rather than combinational logic; MOSI changes on
the falling edge and MISO is sampled around the rising edge, which is correct
SPI mode 0.

The problems are not in what it does today — they're in the margins. The three
that matter:

1. The MISO sampling scheme leaves you **4 ns** of margin, and gets *worse* if
   you raise the clock. (#1)
2. Nothing in the design knows about **tCEM**, the 8 µs PSRAM refresh deadline.
   It's the single constraint that shapes a real memory controller. (#2)
3. `make sim` **cannot show you the UART output at all** — the debug path is
   dead in simulation, which is why #4 went unnoticed. (#5)

---

## Findings

### 1. MISO is sampled half a bit too early — 4 ns of margin at 25 MHz `[verified]`

`psram.v:85-87`. The sample happens on the same `clk` edge that launches the
SCLK rising edge:

```verilog
if (clkdiv2) begin              // rising
    rdata[bit_count] <= miso;   // <-- sampled here
    ...
```

Functionally that captures the right bit: the PSRAM drove it on the preceding
SCLK falling edge. But it means the **entire** round trip has to complete inside
**one core clock period**:

```
FPGA clk->pin (SCLK)  +  PSRAM tCO  +  pin->FPGA (MISO)  <  20 ns
```

Sweeping tCO in simulation puts the cliff at exactly 20 ns of round trip:

| PSRAM tCO | result |
|---|---|
| 6 … 12 ns | pass |
| **13 ns** | **fail — all 51 transfers** |

With tCO = 8 ns (the datasheet figure for this family) plus ~5 ns out and ~3 ns
back, you're using 16 of 20 ns. That's 4 ns before you count FPGA input setup
and any PVT spread. It works on your desk. It is not a design you'd ship, and it
**gets tighter as you speed up** — at a 100 MHz core clock the budget is 10 ns
and it cannot work.

**Fix:** sample on the SCLK *falling* edge instead — half a bit later, same bit,
double the budget. `sim/spi_master.v` does this (`SAMPLE_LATE=1`) and the cliff
moves from 12 ns to 32 ns `[verified]`:

| PSRAM tCO | as-is | `spi_master` SAMPLE_LATE=1 |
|---|---|---|
| 12 ns | pass | pass |
| 13 ns | **fail** | pass |
| 30 ns | fail | pass |
| 33 ns | fail | fail |

Exactly one core clock period of extra margin, as predicted. This is the
standard trick for a fast SPI master and it costs nothing.

When you go faster still, add an explicit `SB_IO` input register on MISO so the
pad-to-fabric delay leaves the setup path, and put SCLK/MOSI/CE# through `SB_IO`
output registers so they leave the chip with matched delay.

### 2. Nothing enforces tCEM — the 8 µs refresh deadline `[verified]`

This is the finding that matters most for where you're going.

PSRAM is DRAM with an SRAM interface. It self-refreshes, but only while CE# is
**high**. The ESP-PSRAM64H / APS6404L family specifies **tCEM = 8 µs maximum
CE# low time**. Exceed it and you don't get an error — you get silently
corrupted memory, in rows you weren't even touching.

Your current 96-bit transaction holds CE# low for 3.86 µs, so you are fine
*today*, by luck. Here's where the wall is at 25 MHz single-SPI:

| burst | CE# low | |
|---|---|---|
| 96 bits (12 B) | 3.86 µs | ok — today's design |
| 192 bits (24 B) | 7.70 µs | ok, barely |
| **256 bits (32 B)** | **10.26 µs** | **violation** |
| 512 bits (64 B) | 20.50 µs | violation |

So at 25 MHz single-SPI your maximum transaction is about **24 bytes**. A
32-byte cache line — the obvious first thing you'd build — already breaks it.

This is why the reference design (see the roadmap doc) runs QPI at ~100 MHz: at
4 bits/clock and 100 MHz the same 8 µs buys you ~400 bytes, so a 32-byte line
is comfortable. **tCEM is the reason QPI isn't optional for you — it's not
about bandwidth, it's about being allowed to finish the transaction.**

Build the guard into the controller: a counter that force-deasserts CE# before
8 µs and splits the burst. `sim/psram_model.v` asserts on violations so your
testbench catches it.

### 3. Power-up: no tPU delay, and CE# starts asserted

`ce`, `sclk`, `mosi` and `rvalid` are `output reg` with no initial value. iCE40
flops come out of configuration at 0, so **RAM_CE_B starts low — the PSRAM is
selected** from the moment the bitstream loads until the first `IDLE` cycle. No
clocks are issued in that window so nothing is actually corrupted, but it's
free to fix and it removes the X's from simulation.

More importantly, this family needs **tPU ≈ 150 µs** after power-up before the
first transaction, and the design starts hammering it immediately. Add a
power-on counter. While you're there, the documented reset sequence is `0x66`
then `0x99`.

```verilog
output reg ce   = 1'b1,
output reg sclk = 1'b0,
output reg mosi = 1'b0,
output reg rvalid = 1'b0,
```

### 4. `rvalid` is generated but never used — 99% of printed values are torn `[verified]`

`psram.v:45-46` declares `wire rvalid`, `SPI` drives it, and **nothing consumes
it**. `RegisterToUART` free-runs off `uart_ready` and latches `spi_data`
whenever its own nibble counter happens to wrap — with no relationship to the
SPI transaction.

Since `IDLE` lasts only one or two cycles, the SPI master is transacting
essentially all the time, so the latch almost always lands mid-transfer.
Measured over 4 ms of simulated time:

```
latches=347   torn(mid-transfer)=344   => 99% of printed values are TORN
```

You haven't seen this because Read ID returns the **same value every time**, so
tearing between two identical transfers is invisible. The moment `rdata` varies
— i.e. the moment you read actual memory — the terminal will show you halves of
two different transactions stitched together, and it will look like a PSRAM
problem rather than a display problem.

**Fix:** latch on `rvalid`, not on the UART's own counter.

```verilog
always @(posedge clk)
    if (rvalid) snapshot <= rdata;   // stable for the whole print
```

and feed `snapshot` to `RegisterToUART`.

### 5. The debug UART never transmits in simulation `[verified]`

`psram.v:167`:

```verilog
reg [9:0] data;        // no initial value, and this copy has no reset
```

`o_ready` is gated on `!(|data)`. With `data` unknown, `|data` is X, so
`o_ready` is X forever and **the UART never sends a byte in simulation** —
under `-DBENCH`, without it, at any `clk_divider`. Verified by sweeping:

```
START_VALUE=2   -> o_ready pulses in 500us = 0   (DEAD)
START_VALUE=198 -> o_ready pulses in 500us = 0   (DEAD)
```

On hardware it works, because iCE40 flops configure to 0. So the *one* output
path you'd use to debug this design is the one path you cannot simulate — which
is exactly why #4 has gone unnoticed.

One-line fix, after which it transmits correctly in both configurations
`[verified]`:

```verilog
reg [9:0] data = 0;
initial o_ready = 1'b0;
```

Note `riscv/emitter_uart.v` is the *same* module with an `i_rst` port that
already handles this. Two diverged copies of one module in one repo — worth
collapsing into a single file both projects include.

### 6. `$clog2` off-by-one — breaks at exactly 128 bits `[verified]`

Two places compute a counter width as `$clog2(N)` where the counter must reach
`N`. `$clog2(N)` is only wide enough for `N-1`.

`psram.v:110`, `RegisterToUART`:

```verilog
reg [$clog2(width/4)-1:0] cnt = 0;   // must reach width/4
```

At `width=96` it needs to count to 24 and `$clog2(24)=5` bits hold 31 — fine by
luck. At `width=128` it needs 32 and still gets 5 bits:

```
width=96  : cnt is 5 bits, must count to 24 -> newlines = 16  (OK)
width=128 : cnt is 5 bits, must count to 32 -> newlines = 0   (BROKEN)
width=256 : cnt is 6 bits, must count to 64 -> newlines = 0   (BROKEN)
```

Broken means the counter never reaches the wrap value, so it never latches new
data and never emits a newline — it just prints forever. 128 bits is the first
width you'd pick when you extend this (16 bytes). `psram.v:66` has the same
shape (`$clog2(BIT_CNT)`), currently safe only because 95 < 127.

**Fix:** `$clog2(N+1)` in both places.

### 7. `rdata` as a bit-indexed register costs far more logic than a shift register

```verilog
reg [BIT_CNT:0] rdata;
rdata[bit_count] <= miso;     // 96 flops, each with its own decoded enable
mosi <= data_out[bit_count];  // 96:1 mux
```

Variable-index assignment synthesises to a 96-way address decoder plus 96
enable-gated flops. A plain shift register is the same 96 flops with **no**
decoder and no mux. On a 5280-LUT part that difference is worth having, and it
scales badly as you widen the transfer.

`sim/spi_master.v` is shift-register based. (I couldn't get yosys installed in
this environment, so I have no LUT numbers for you — worth a `make psram.rpt`
before and after.)

### 8. Port declared with a `localparam` declared later in the body

```verilog
output reg [BIT_CNT:0] rdata,    // BIT_CNT is a localparam further down
```

Icarus accepts it; not all tools will, and it can't be overridden per instance.
Make it a real parameter: `module SPI #(parameter WIDTH = 96) (...)`.

### 9. The testbench doesn't test the thing

`bench_iverilog.v`:

```verilog
reg miso = 0;          // declared, never connected to anything
SPI psram(
   .miso(mosi),        // MISO tied to MOSI - a loopback
   .mosi(mosi),
```

so it verifies that the module can hear itself talk. There's no model, no
checker, no `$display`, no pass/fail — and `$dumpvars` doesn't run until #380,
after the interesting start-up. `rvalid` isn't connected, and `SOC` is never
instantiated, so the UART path is untested (and per #5 couldn't run anyway).

`` `define BENCH `` at the top of the bench is also ineffective for `psram.v`,
because the Makefile compiles `psram.v` **first**. It works only because the
Makefile separately passes `-DBENCH`. Remove the define and keep it in one
place.

`sim/` now contains a real model and self-checking benches.

### 10. Makefile: timing constrained to 10 MHz on a 50 MHz design

```make
nextpnr-ice40 ... --freq 10 ...
icetime -d up5k -c 10 -mtr $@ $<
```

The PLL is `DIVR=0, DIVF=66, DIVQ=4` → `12 × 67 / 16 =` **50.25 MHz**. Modern
nextpnr auto-derives a constraint for PLL outputs, so you're probably being
checked correctly in spite of this — but the `icetime -c 10` report is
meaningless, and `--freq 10` misdescribes the design. Set them to the real
number so the report tells you something.

Also: the `$(PROJ)_tb*` rules reference a `psram_tb.v` that doesn't exist, and
`assemble` / `compile` were copy-pasted from `riscv/` and reference `mandel.c`,
`bram.ld`, `print.o` — none of which are in this directory. Dead rules.

### 11. Smaller things

- `assign LEDS = 1;` — `LEDS` is `[4:0]`, so this lights LED0 only. Presumably
  intended as an "alive" light; `5'b00001` says so explicitly.
- `input RESET` on `SOC` is declared and never used.
- `RegisterToUART` sets `tx_data` on the same edge the UART latches `i_data`, so
  the UART is consistently one character behind. Output is correct after a
  single junk byte at start-up. Harmless, worth a comment.
- `bit_count` decrements past 0 and wraps to 127 on the last bit. `IDLE`
  reloads it, so it's harmless — but it's load-bearing luck.
- `riscv/riscv.v:497`: comment says `baud = 12Mhz/6 = 2Mbaud` with
  `clk_divider=12`. The actual baud rate is 12 MHz / 12 = **1 Mbaud**. Worth
  fixing before it costs someone an hour on a terminal setting.

---

## Board-level findings that affect this gateware

These come from reading the KiCad files in the PMOD repo against `icebreaker.pcf`.
Full detail in that repo's `REVIEW.md`; the parts that bite *this* code:

### A. `SIO0` and `SIO1` mean opposite things in the two repos

The PSRAM datasheet says SOIC-8 pin 5 = `SI`/`SIO0` and pin 2 = `SO`/`SIO1`.

- The **schematic** wires net `SIO0` to U1 pad **2** and net `SIO1` to U1 pad
  **5** — i.e. the board's net names are swapped relative to the chip.
- The **PCF** aliases `SIO0` and `RAM_SI` to the same pin (45), and `SIO1` and
  `RAM_SO` to the same pin (2) — i.e. chip-correct.

Both describe the same copper, and single-SPI works today because `RAM_SI` /
`RAM_SO` are used, not the `SIOn` aliases. But the moment you write a QPI
controller with a `sio[3:0]` bus, **whichever naming you follow decides whether
lanes 0 and 1 are crossed**, and a nibble-swapped QPI read is a genuinely
horrible thing to debug. Pick one convention and fix the other repo.

### B. SD_DAT3 (the SD card's chip select) is left floating

`psram.v` doesn't drive pins 3 and 47 at all. Pin 47 is net `SIO3`, which is the
microSD's **DAT3 — its chip select in SPI mode** — and there is no pull-up on
the board (see C). With a card inserted, CS floats; if it floats low the card
may drive DAT0, which is **pin 2, the same wire as the PSRAM's MISO**. That's
bus contention on the one signal you're trying to read.

You may well have been testing with an empty socket. **Drive pin 47 high** in
the gateware — one line, and it removes a whole class of "the PSRAM is flaky"
debugging.

```
set_io -nowarn SD_CS 47      # and assign SD_CS = 1'b1;
```

### C. PSRAM and SD share SIO0..3 — and QPI drives the SD's chip select

The two devices share the four data lines; only the clocks (`RAM_CLK` / `SD_CLK`)
and selects are separate. Mapping the nets through to each device:

| pin | PSRAM | microSD |
|---|---|---|
| 45 | SIO0 (SI) | DAT2 |
| 2  | SIO1 (SO) | **DAT0 (MISO in SPI mode)** |
| 3  | SIO2 | DAT1 |
| 47 | SIO3 | **DAT3 (CS in SPI mode)** |
| 46 | SCLK | — |
| 48 | CE# | — |
| 4  | — | CLK |
| 44 | — | CMD (MOSI in SPI mode) |

Two consequences:

- **Good news:** in single-SPI mode both devices can live on the bus with no
  muxing. Their MISOs are the same pin and both tri-state when deselected, and
  they have independent clocks and selects. Your SD SPI pinout is
  `CLK=4, MOSI=44, MISO=2, CS=47`.
- **Watch out:** PSRAM QPI uses pin 47 as SIO3, which *is* the SD's CS. It's
  survivable, because `SD_CLK` is a dedicated pin — with no clock edges the card
  can't change state no matter what CS does. But never interleave: finish an SD
  transaction completely (and let the card release DAT0) before starting QPI
  traffic. If you ever want 4-bit SD mode, note the DAT lanes are scrambled
  (DAT0→45? no: DAT0=pin2, DAT1=pin3, DAT2=pin45, DAT3=pin47) and need
  remapping in gateware.

---

## Suggested order of work

1. `data = 0` in the UART (#5) — without it you can't simulate anything.
2. Latch `rdata` on `rvalid` (#4).
3. Drive SD_CS high (#B).
4. Move the MISO sample to the falling edge (#1).
5. `$clog2(N+1)` (#6), init `ce = 1` (#3), fix the Makefile frequencies (#10).
6. Then real reads/writes (`0x02` write, `0x0B` fast read), a memory test, and
   only then QPI — with the tCEM guard built in from the start (#2).

Steps 1–5 are all small. Step 6 is the actual project, and the roadmap doc
covers what it should look like.
