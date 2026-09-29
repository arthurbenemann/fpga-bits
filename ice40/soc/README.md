# PSRAM SoC

The `../riscv` pipelined core at 25.125 MHz (overclocked; `SLOW=1` builds an in-spec 12.56 MHz
version) with 8 MB PSRAM (PMOD-PSRAM-SDCARD on PMOD 2), 640x480 DVI out showing a 320x200 8-bit
framebuffer (1BitSquared 12-bit DVI PMOD on PMOD 1A/1B), UART at 3.14 Mbaud and a bootloader in BRAM.

At power-on the bootloader copies the program bundle from SPI flash and runs the menu:
mandel, coremark, memtest, pi, chess and Doom (from flash). Pick with up/down + Enter or the number.

- `make soc-prog`: build and flash the bitstream. The overclock is placement dependent: if memtest
  shows errors, try another `--seed` (a known good one is kept in `out/`).
- `make flash-bundle`: build all programs and write the bundle to flash (1 MB offset).
- `make -C doom flash`: write Doom to flash (2 MB offset).
- `make load IMG=pi.img`: upload and run one program without flashing.
- `./load.py --attach --keys`: terminal to the running program, with real key press/release
  events (needs the `input` group); plain `./load.py --attach` sends typed keys.

Power-cycle after writing a new bundle: the old one stays in PSRAM until then.
