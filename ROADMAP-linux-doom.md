# Roadmap: from the PSRAM bring-up to Linux, and to Doom

Companion to `psram/REVIEW.md`. This is about where the `riscv/` core and the
`psram/` controller are heading, and what the numbers say is actually
achievable on an iCEBreaker (iCE40UP5K) with your 8 MByte PSRAM PMOD.

## The short version

Three things, in order of how much they should change your plan:

1. **You do not need Linux to run Doom, and Linux would make Doom worse.**
   Bare-metal Doom on a UP5K with exactly your 8 MB of QSPI PSRAM is a *solved
   problem* — there's a working reference design (below) on the same FPGA, the
   same memory size, the same board. Linux on the same chip runs at 15–20 MHz
   with MMU overhead on top. If the goal is Doom, Linux is a detour that costs
   you frame rate.

2. **Your board has 8 MB. Linux on this FPGA wants 32 MB.** That's not a
   tuning problem, it's a 4× capacity problem, and it's the one hard blocker in
   this whole document. Details and the fix in "Linux, honestly".

3. **8 MB is not an awkward middle size — it is precisely the right size for
   Doom.** `DOOM1.WAD` (shareware) is 4.2 MB and Doom's zone heap wants ~2–3
   MB. That's why the reference design uses 8 MB. You built the right board for
   Doom and the wrong board for Linux.

So: **Doom first, on VGA, bare metal.** Then Linux as its own project, with a
bigger PMOD.

---

## The reference design — read this before writing anything

[`smunaut/ice40-playground/projects/riscv_doom`](https://github.com/smunaut/ice40-playground/tree/master/projects/riscv_doom)
is Doom running on an iCEBreaker. I read the RTL; here is its architecture,
because it answers most of the design questions you're about to hit:

| | |
|---|---|
| CPU | VexRiscv — AXI instruction bus (with burst), Wishbone data bus |
| CPU clock | `clk_1x` = 0.925 × 25.175 ≈ **23.3 MHz** |
| Memory clock | `clk_4x` = 4 × 25.175 = **100.7 MHz** |
| Cache | `mc_core`: 4-way, **32-byte lines**, 24-bit address space |
| PSRAM ctrl | `qpi_memctrl`: `CMD_READ=0xEB`, `CMD_WRITE=0x02`, `DUMMY_CLK=6`, `PAUSE_CLK=8`, `N_CS=2`, `PHY_SPEED=4` |
| PHY | `qpi_phy_ice40_4x` — QPI at 4× the CPU clock |
| Framebuffer | `2 × SB_SPRAM256KA` = **64 KB** = 320×200 @ 8bpp, exactly |
| Video out | palette → 640×400 (and 640×480 timings present), 12-bit HDMI PMOD on 1A+1B |
| PSRAM wiring | on the **on-board flash QSPI pins**, second chip select on pin 37 |

Four things to take from that:

- **320×200 at 8 bits per pixel is 64,000 bytes, and two SPRAMs are 65,536.**
  Doom's native resolution fits the UP5K's framebuffer memory with 1.5 KB to
  spare. This is not a coincidence you should fight — build the framebuffer in
  SPRAM, keep the other two SPRAMs (64 KB) for CPU stack and hot data, and
  leave PSRAM for the WAD and the zone heap.
- `PAUSE_CLK=8` is the **tCEM/tCPH guard** — 8 idle clocks with CE# high
  between transactions. It's in the reference because it has to be. See
  finding #2 in the review.
- `CMD_READ=0xEB` with **6 dummy cycles** is the QPI fast-read setup for this
  PSRAM family. You can lift those constants directly.
- The reference puts the PSRAM on the **flash pins**, not a PMOD, and uses both
  PMODs for video. You'll have to resolve that differently — see "Pins".

---

## Why QPI isn't optional

Not for bandwidth. For **tCEM** — the 8 µs maximum CE#-low time (review #2,
verified in simulation). It caps how much you can move per transaction:

| configuration | max payload per transaction | peak |
|---|---|---|
| single-SPI @ 25 MHz (today) | **~20 bytes** | 3.1 MB/s |
| QPI x4 @ 50 MHz | ~190 bytes | 25 MB/s |
| QPI x4 @ 100 MHz | ~390 bytes | 50 MB/s |

At today's 25 MHz single-SPI a **32-byte cache line does not fit inside the
refresh window**. You physically cannot build a conventional cache on top of
the current controller. At 100 MHz QPI a 32-byte line takes ~0.86 µs including
the pause — 9× inside the limit.

And instruction fetch without a cache is hopeless: one uncached 32-bit fetch
over single-SPI is 8+24+32 = 64 SCLK = **2.56 µs**, i.e. ~0.4 MIPS. Doom needs
single-digit MIPS minimum.

**Caveat I want to flag honestly:** the reference runs 100 MHz QPI over short
board traces to a chip on the PCB. You'd be running it through a PMOD header
with no series termination and no ground plane between the connectors. Expect
to back off — 50–70 MHz is a realistic first target. 33 Ω series resistors at
the FPGA end would help, and that's a change for a board revision.

---

## Pins: PSRAM and video want the same connectors

The reference uses a 12-bit video PMOD spanning **1A + 1B**, which is where
your PSRAM lives. Options, best first:

1. **Move the PSRAM PMOD to PMOD2.** iCEBreaker's PMOD2 is a standard 12-pin
   connector with 8 IO (pins 18, 19, 20, 21, 23, 25, 26, 27 — currently the
   LED/button PMOD). Your board needs exactly 8. Then 1A+1B are free for the
   full 12-bit VGA or DVI PMOD. **This is a `.pcf` edit and physically moving
   one board.** You lose the LED/button PMOD, which you won't miss.
2. **Keep PSRAM on 1A, put a single-PMOD VGA on 1B.** 8 pins = 2:2:2 RGB +
   HSync + VSync = 64 colours. Doom's 256-entry palette dithers down to 64
   acceptably, or pick a fixed 64-colour subset. Cheapest in effort, worst in
   looks.
3. **Piggyback the PSRAM on the flash pins** like the reference (14/17/12/13/15
   + a second CS on 37). Matches the reference exactly, but means jumper wires
   from a PMOD board to the flash, which is a signal-integrity downgrade at
   QPI speeds. Not worth it given option 1.

Go with option 1.

---

## Terminal Doom vs VGA Doom

You asked about both. The numbers:

**VGA/DVI** — 320×200×8bpp out of SPRAM, palette lookup, doubled to 640×400.
Costs ~64 KB of SPRAM and a few hundred LUTs. The CPU writes pixels and the
video pipeline is entirely independent of it. This is the right answer.

**Terminal over UART** — more interesting than it looks, because the
iCEBreaker's FT2232H will do **12 Mbaud**, not the 115200 you're probably
assuming.

Using half-block rendering (`▀`, U+2580 — foreground is the top pixel,
background the bottom, so one character cell = 2 vertical pixels) at 80×50
cells = 80×100 pixels, with 256-colour ANSI (`\e[38;5;Nm\e[48;5;Nm`, ~25 bytes
per cell worst case):

| baud | bytes/s | full frame (100 KB) | delta frame (~50 KB) |
|---|---|---|---|
| 115200 | 11.5 KB/s | 8.7 s | 4.3 s |
| 1 M | 100 KB/s | 1.0 s | 0.5 s |
| 3 M | 300 KB/s | 0.33 s | 0.17 s |
| **12 M** | **1.2 MB/s** | 0.08 s (12 fps) | 0.04 s (**24 fps**) |

So the *link* is fine at 12 Mbaud. Two things will actually stop you:

- **The terminal emulator.** Very few handle 1.2 MB/s of escape sequences.
  Budget for the terminal being the bottleneck, not the wire.
- **The encoding cost on the CPU.** Turning 4000 cells into escape sequences
  every frame is thousands of instructions per frame on a ~2 MIPS soft core —
  plausibly *more* work than Doom's renderer. This is the real killer.

If you want terminal output, **do the ANSI encoding in gateware**: a small state
machine that walks the 64 KB SPRAM framebuffer, compares against a previous-
frame copy, and emits escape sequences straight into the UART. The CPU then
does nothing but render into SPRAM, exactly as it would for VGA, and you can
switch between the two outputs without touching the game code.

That's genuinely a nice module to write and it's maybe 300 LUTs. But do VGA
first — it's less work and it's the thing you'll actually want to look at.

---

## Milestones

Each step is independently demonstrable, which matters because this is a long
project.

**M0 — finish the SPI bring-up.** Items 1–5 in `psram/REVIEW.md`. End state:
`0D5D` printed reliably, and a `make check` that passes.

**M1 — PSRAM as memory.** Write (`0x02`) and read (`0x0B` fast read) with a
runtime-loadable command register instead of the hardcoded `data_out`. Then a
proper memory test: address-in-address, walking ones, and a long pseudorandom
soak. **The soak test is the one that finds tCEM bugs** — they show up as bit
rot in addresses you touched minutes ago, not as failures at the access.

**M2 — QPI.** Enter with `0x35`, read with `0xEB` + 6 dummy cycles. Build the
tCEM guard in from the start. Re-run M1's soak at each clock speed and find
where your PMOD actually stops working — record that number, you'll need it.

**M3 — SPRAM for the CPU.** Before touching PSRAM from the CPU, replace
`riscv/riscv.v`'s `Memory` module (1536 words of BRAM = 6 KB) with
`SB_SPRAM256KA`. That's 6 KB → 128 KB for almost no logic, and it's the
single biggest capability jump available to you right now. Plenty to run real
C programs before any of the hard memory work.

**M4 — cache + PSRAM behind the CPU.** 4-way, 32-byte lines. Note the
reference's `ADDR_WIDTH(24)` — 16 MB of address space for an 8 MB device.

**M5 — video.** 320×200×8bpp in 2 SPRAMs, palette, 640×400 out. Get a test
pattern up, then a bitmap, then hook the CPU to it.

**M6 — Doom.** Use [`smunaut/doom_riscv`](https://github.com/smunaut/doom_riscv),
which is the bare-metal RISC-V port everyone else uses; don't start from
`doomgeneric`. Keep the WAD in SPI flash (iCEBreaker has 16 MB) and read lumps
on demand — Doom's `W_CacheLumpNum` already works that way, so you need a
handful of stub functions, not a filesystem. Only bother with SD + FatFs if you
want to swap WADs without reflashing.

### A note on the CPU

`riscv/riscv.v` is a clean RV32I from Bruno Levy's tutorial, and it's fine for
M3. For M4 onward it needs: the **M extension** (Doom does a lot of multiplies
— without it every one is a libgcc call), an instruction cache interface that
can issue bursts, and CSRs/traps/a timer if you ever want interrupts.

That's most of a new core. At M4, swap in **VexRiscv** (what the reference
uses) or **picorv32**. Keeping your own core is a great way to learn how one
works — which it clearly already has been — but it's not the way to get to
Doom, and there's no shame in that. Your core has taught you the thing it was
built to teach.

---

## Linux, honestly

The reference here is [`smunaut/iCE40linux`](https://github.com/smunaut/iCE40linux),
which does run Linux on an iCE40UP5K. What it requires:

| | |
|---|---|
| RAM | **32 MByte** — "4 × 64 Mbit HyperRAM or 4 × 64 Mbit SPI PSRAM" |
| CPU | VexRiscv, RV32I; the BIOS **emulates** atomics and unaligned access |
| Clock | **15 MHz** default (nextpnr fmax), 20 MHz overclocked |
| Flash | ~16 MB: 128k bitstream, 3k BIOS, 8k DTB, 4608k kernel, 10240k UBIFS |

**Your board has 8 MB. This wants 32 MB.** And no-MMU Linux isn't a way out:
the reported floor for RV32 nommu is around 12 MiB, with 8 MiB failing in
`binfmt_flat` with `ENOMEM`. 8 MB is below the floor on both paths.

Three ways forward, if you want Linux:

1. **Buy the capacity.** [Machdyne's QQSPI PSRAM32](https://machdyne.com/product/qqspi-psram32/)
   is a 12-pin Pmod carrying 32 MB as four QSPI dies on a shared x4 bus, selected
   by two chip-select pins. Same bandwidth as yours, 4× the capacity, same form
   factor — and `iCE40linux` already has a `MEM=qpi` build for SPI PSRAM. This
   is the low-effort path, and it's also what sylefeb used to run Doom on an
   *IceStick*.

2. **Spin a rev02 of your own PMOD** doing the same thing: four ESP-PSRAM64H
   dies, shared SIO[3:0] and SCK, two CS pins decoded to 4. Pin budget on one
   PMOD: 4 SIO + SCK + CS0 + CS1 = 7, leaving 1. The SD card needs CMD and can
   share SCK (it ignores clocks while its CS is high), so 8 pins covers
   32 MB + SD if you're careful — and it fixes the pull-up, decoupling and
   termination problems in the board review at the same time. This is the fun
   option.

3. **Don't.** Bare metal on 8 MB gets you Doom, and a lot else.

And to close the loop on the original goal: **Linux is not a step toward Doom.**
At 15–20 MHz with the kernel and page tables competing for the same QSPI PSRAM,
Doom under Linux on this chip would be slower than Doom on bare metal at
23 MHz. The published iCE40 Doom figures are already in the sub-1-fps to
low-fps range on comparable hardware (sylefeb measured ~0.3 fps rising to
~0.5 fps on an *IceStick*, a far smaller FPGA — a UP5K build should be
meaningfully better, but I don't have a verified frame rate for the iCEBreaker
one to quote you).

Run Linux on this board because booting a kernel on something you built is a
genuinely great thing to have done. Just don't run it to get to Doom.
