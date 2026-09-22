# Hooking the CPU to PSRAM instead of the BRAM block

Answers "what has to change in `riscv/riscv.v` so the CPU uses PSRAM instead of
the local `Memory` block". Companion to `psram/REVIEW.md` and
`ROADMAP-linux-doom.md`.

**Short answer: three things block it, and only one of them is the PSRAM
controller.**

1. The CPU has **no stall mechanism**. Its FSM assumes memory answers in
   exactly one cycle. (Confirmed: no step in `riscv/tutorial/` — through
   `step21.v` — has a busy/stall signal. It was never built in.)
2. **SPRAM cannot be initialised from the bitstream**, so the moment you stop
   using BRAM you need a boot ROM.
3. Without a cache, **instruction fetch from PSRAM is ~0.4 MIPS** — unusable.
   Code has to live in SPRAM first.

So do it in three stages. Stage A and B are both useful on their own.

---

## Stage A — BRAM → SPRAM (6 KB → 128 KB)

The biggest capability jump available, and it needs **no** stall logic: SPRAM
has the same 1-cycle registered read as BRAM.

`SB_SPRAM256KA` is 16384 × 16 bits (32 KB). Two side by side give you a 32-bit
wide 64 KB memory; four give 128 KB with one bank bit.

Two gotchas:

- **No `$readmemh`.** SPRAM has no initialisation path from the bitstream, so
  `initial $readmemh("assemble.hexdump", MEM)` in `Memory` stops working. You
  need a small BRAM boot ROM that copies the program into SPRAM at reset —
  from SPI flash, or over the UART while you're iterating. The reference design
  does exactly this: `rtl/soc_bram.v` is a `$readmemh`-initialised BRAM with
  `AW=8` (1 KB) and `fw_boot/boot.S` copies the app in from flash at
  `0x00100000`.
- **Byte writes.** SPRAM has `MASKWREN[3:0]`, which is **nibble** granular, not
  byte. Each of your `mem_wmask` bits has to drive two mask bits. Check the
  polarity against the datasheet — `vid_framebuf.v` in the reference design is
  a known-good example of the mapping.

Then update the linker script:

```ld
MEMORY {
   RAM (RWX) : ORIGIN = 0x00000000, LENGTH = 0x20000   /* 128 kB SPRAM */
}
```

and `start.s`'s `li sp,0x1800` → `li sp,0x20000`.

That alone gets you from 6 KB to 128 KB, which is enough to run real C.

## Stage B — PSRAM as a data-only region

This is the useful intermediate: **code and stack stay in SPRAM, PSRAM holds
bulk data.** No cache needed, because you're not fetching every instruction
over SPI — only the occasional load/store goes slow. Good enough for big
arrays, a framebuffer, a WAD.

### B.1 Give the CPU a stall input

Add two inputs to `Processor`:

```verilog
input mem_rbusy,   // read in flight, mem_rdata not valid yet
input mem_wbusy,   // write in flight
```

and make the two wait states actually wait. In the FSM (`riscv.v:98-133`):

```diff
     WAIT_INSTR: begin
-        instr <= mem_rdata;
-        state <= FETCH_REGS;
+        if (!mem_rbusy) begin
+            instr <= mem_rdata;
+            state <= FETCH_REGS;
+        end
     end
...
     WAIT_DATA: begin
-        state <= FETCH_INSTR;
+        if (!mem_rbusy) state <= FETCH_INSTR;
     end
     STORE: begin
-        state <= FETCH_INSTR;
+        state <= WAIT_STORE;
     end
+    WAIT_STORE: begin
+        if (!mem_wbusy) state <= FETCH_INSTR;
+    end
```

`state` is already `reg [2:0]` and you're using 0-6, so `WAIT_STORE = 7` fits
with no widening.

**Don't miss this one** — `riscv.v:159`:

```diff
-wire writeBackEn = (state == EXECUTE && !isBranch && !isStore && !isLoad) || (state == WAIT_DATA);
+wire writeBackEn = (state == EXECUTE && !isBranch && !isStore && !isLoad)
+                || (state == WAIT_DATA && !mem_rbusy);
```

Without it, a stalled load writes garbage into `rd` on every busy cycle. The
final write happens to be correct, so it *works* — but it's writing nonsense to
the register file for hundreds of cycles, and it will bite you the first time
you add anything that observes the register file mid-instruction.

Nothing else needs to change: `mem_rstrb` is already a clean one-cycle pulse
(`FETCH_INSTR` and `LOAD` each last exactly one cycle), `mem_addr` is already
held stable across `WAIT_INSTR` / `WAIT_DATA`, and making `STORE` one cycle
followed by `WAIT_STORE` keeps `mem_wmask` a one-cycle pulse so the existing
memory-mapped IO writes are unaffected.

Cost when nothing is slow: **one extra cycle per store**, zero otherwise.

### B.2 Memory map and decode

`isIO = mem_addr[22]` is too crude once there are three targets. Keep bit 22
for IO so `start.s` (`IO_BASE = 0x400000`) and the existing firmware keep
working, and put PSRAM up top:

| range | target | latency |
|---|---|---|
| `0x0000_0000`–`0x0001_FFFF` | SPRAM, 128 KB — code, stack, hot data | 1 cycle |
| `0x0040_0000` | memory-mapped IO | 0 cycles |
| `0x8000_0000`–`0x807F_FFFF` | PSRAM, 8 MB — bulk data | hundreds of cycles |

```verilog
wire isIO    =  mem_addr[22];
wire isPSRAM =  mem_addr[31];
wire isSPRAM = !isIO && !isPSRAM;

assign mem_rdata = isPSRAM ? psram_rdata :
                   isIO    ? IO_rdata    : SPRAM_rdata;

assign mem_rbusy = isPSRAM & psram_busy;
assign mem_wbusy = isPSRAM & psram_busy;
```

`psram_busy` must be **registered** so it is already high when the CPU reaches
`WAIT_INSTR` / `WAIT_DATA` / `WAIT_STORE` — the controller latches the request
on the strobe cycle and raises busy on the same edge.

### B.3 What the controller has to become

This is the part where the current `SPI` module doesn't extend — it has to be
replaced. Today it free-runs: hardcoded 96-bit `data_out`, no request input, no
address, `IDLE` lasts one cycle and it immediately starts again. There is no
seam to attach a CPU to.

What it needs instead:

- a request interface — `valid`/`ready`, address, write data, byte mask,
  read/write;
- a runtime-assembled command rather than a constant (`0x02` write, `0x0B` fast
  read, later `0xEB` QPI read + 6 dummy cycles);
- the **tCEM guard** — a counter that force-deasserts CE# before 8 µs and
  splits the burst. At 25 MHz single-SPI your ceiling is ~20 bytes per
  transaction (measured, `psram/sim/`);
- the MISO sampling fix, `psram/REVIEW.md` #1.

`psram/sim/spi_master.v` is the starting point: shift-register based, proper
reset, `start`/`busy`/`done` handshake, tCPH guard. It needs the address/command
assembly and the tCEM counter added.

## Stage C — code in PSRAM

Only worth doing with a cache in front, and only after QPI. A 32-byte line
doesn't fit in the refresh window at 25 MHz single-SPI, so **QPI is a
prerequisite, not an optimisation**. See `ROADMAP-linux-doom.md`.

At that point you're also past what this core can usefully do — it has no M
extension, no CSRs, no traps — and swapping in VexRiscv or picorv32 is the
shorter path.

---

## Rough latency, for calibration

Single-SPI at 25 MHz, one 32-bit access = 8 command + 24 address + 32 data =
64 SCLK ≈ **2.56 µs**, i.e. ~64 CPU cycles at 25 MHz.

- As **instruction fetch** (stage C without a cache): ~0.4 MIPS. Unusable —
  this is why stage B keeps code in SPRAM.
- As **occasional data** (stage B): if 1 in 50 instructions touches PSRAM,
  you're paying ~1.3 extra cycles per instruction on average. Perfectly fine.

That ratio is the whole argument for doing stage B before stage C.
