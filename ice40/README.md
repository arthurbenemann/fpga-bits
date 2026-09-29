# iCE40 projects (iCEBreaker, iCE40UP5K)

- `riscv/`: RISC-V softcore from the learn-fpga tutorial (RV32I + Zmmul, 3-stage `pipe.v`), UART, Mandelbrot accelerator.
- `soc/`: that core as a SoC with 8 MB PSRAM, SPI-flash boot, a 320x200 HDMI framebuffer and a program menu.
- `soc/doom/`: Doom (doomgeneric) running on the PSRAM SoC.
- `tdc/`: time-to-digital converter experiment (carry-chain delay line, ~0.25 ns).
- `led_driver_tlc6c5912/`: shift-register driver for a TLC6C5912 RGB LED board.

Toolchain: yosys, nextpnr-ice40, icestorm, riscv64-unknown-elf gcc + picolibc (see `riscv/README.md`).
