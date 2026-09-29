# RISC-V SoC

A small RISC-V computer on an iCE40UP5K (iCEBreaker), fast enough to play Doom.

- **CPU:** RV32I + Zmmul (hardware multiply), 3-stage pipeline (`../riscv/pipe.v`), 25.125 MHz
  (overclocked; nextpnr's fmax is ~17 MHz). CoreMark 50.9 (2.0/MHz); Doom ~11 fps in low detail.
- **Memory:** 6 KB BRAM (bootloader, stack); 8 MB QSPI PSRAM behind a 64 KB direct-mapped
  write-through cache; 128 KB framebuffer. All four SPRAMs are used, about 77% of the logic cells.
- **I/O:** 640x480@60 DVI showing 320x200 with a 256-colour 12-bit palette (plus a double-buffered
  Doom view), UART at 3.14 Mbaud with 512-byte FIFOs, SPI flash boot, Mandelbrot accelerator.
- **Boards:** PMOD-PSRAM-SDCARD on PMOD 2, 1BitSquared 12-bit DVI PMOD on PMOD 1A/1B.

```
sudo apt install doom-wad-shareware   # once: Doom's data (or put a doom1.wad in doom/)
make flash                            # bitstream, programs and Doom into SPI flash
./load.py --attach --keys             # keyboard and terminal (evdev: needs the 'input' group)
```

The board then boots straight into the menu: up/down + Enter, or the item's number.

Details: the CPU is overclocked (`SLOW=1` builds an in-spec 12.5 MHz version), and whether a
placement works is luck, so the Makefile pins a `SEED` that passes memtest; retest after changing
the hardware. `make load IMG=pi.img` runs one program without flashing. Power-cycle after
reflashing so the new programs load.
