# Measured resource numbers (iCE40 UP5K)

All measured, not estimated — yosys 0.69 + nextpnr-ice40, `--up5k --package sg48`.
The earlier docs had estimates here because no synthesis tool was available;
these supersede them.

**UP5K budget:** 5280 LUT4 · 5280 DFF · 30 EBR (4 kbit each, 15 KB total) ·
**8 DSP (SB_MAC16)** · 4 SPRAM (32 KB each, 128 KB total) · 1 PLL

---

## Multipliers — what the M extension would cost

| what | LUT4 | DFF | DSP | note |
|---|---|---|---|---|
| 16×16→32, `-dsp` | 0 | 0 | **1** | one DSP's native size |
| 16×16→32, LUTs | 683 | 32 | 0 | |
| **32×32→32** (`MUL` only), `-dsp` | **0** | **0** | **3** | |
| 32×32→32, LUTs | 1301 | 32 | 0 | |
| **32×32→64** (`MUL`+`MULH*`), `-dsp` | **48** | **48** | **4** | **the one you want** |
| 32×32→64, LUTs | 2775 | 64 | 0 | 53% of the whole FPGA |
| sequential shift-add, 32 cycles | 143 | 168 | 0 | cheap area, 32 cycles/multiply |

**The headline: a full RV32 `M` multiplier costs 4 of your 8 DSP blocks and
48 LUTs.** Built out of LUTs instead it costs 2775 — a 58× difference. The DSPs
are sitting completely unused in every design in this repo.

`DIV`/`REM` are a separate matter: nobody builds a combinational divider, so
that stays a ~32-cycle sequential unit whatever you do.

## Current designs

| design | LUT4 | DFF | EBR | DSP | |
|---|---|---|---|---|---|
| `psram/psram.v` (master, SPI only) | 324 | 236 | 0 | 0 | |
| `riscv/riscv.v` (master, CPU + Mandelbrot) | **4789** | 274 | 16 | 0 | **91% full** |
| `psram/soc.v` (`riscv-spi` branch, CPU + SPI) | 1139 | 112 | 16 | 0 | 22% after P&R |

### `riscv/riscv.v` is 91% full, and it's almost all Mandelbrot

| | LUT4 | DSP |
|---|---|---|
| Mandelbrot alone, no `-dsp` (**how your Makefile builds it**) | **3685** | 0 |
| Mandelbrot alone, with `-dsp` | 204 | **9** |

Your Makefile runs plain `synth_ice40`, which does **not** infer DSP blocks, so
the three 32×32 multiplies in `Mandelbrot` are being built out of LUTs —
3685 of them. The CPU and all the peripherals together are only ~1100.

Adding `-dsp` would cut that to 204 LUTs, except `Mandelbrot` then wants **9
DSPs and the UP5K has 8**. Narrowing the multiplies (they're 32×32 feeding a
`>>> mandel_shift`, so the full 64-bit product isn't needed) would bring it
under 8.

The `riscv-spi` branch already removes the Mandelbrot hardware, which is why
it's at 1139 LUTs.

## Timing

`psram/soc.v` (`riscv-spi` branch), placed and routed:

```
ICESTORM_LC:   1197/5280   22%
ICESTORM_RAM:    16/30     53%
Max frequency for clock 'CLK': 21.28 MHz
```

**~21 MHz is where this CPU tops out** as currently written. For calibration,
`iCE40linux` runs at 15 MHz and the `riscv_doom` reference at 23.3 MHz — so
this is right in the expected band, and the 50 MHz PLL setting in
`psram/Makefile` is well beyond what the CPU could sustain.

## Toolchain note: `psram/psram.v` no longer synthesises

```
psram.v:55: ERROR: Non-constant range in declaration of \rdata
```

`output reg [BIT_CNT:0] rdata` uses a `localparam` declared later in the module
body. Icarus accepts it; **yosys 0.69 rejects it outright**, so `make` fails on
a current toolchain. `REVIEW.md` #8 listed this as a portability nit — it is
now a hard build failure. The fix is the one already suggested there:

```verilog
module SPI #(parameter WIDTH = 96) (
    ...
    output reg [WIDTH-1:0] rdata,
```

With that change it builds: **324 LUT4, 236 DFF**.
