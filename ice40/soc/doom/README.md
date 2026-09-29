# Doom on the PSRAM SoC

doomgeneric/doom-ascii (cloned into `build/` at a pinned commit) with `dg_uart.c` as the platform
layer: keys from the UART, frames to the HDMI framebuffer in a double-buffered low-detail view,
WAD linked into the image in PSRAM. `fixed_fast.c`, `udiv_fast.c` and `r_draw_fast.c` replace the
slow divisions and the column/span drawers.

- `make WAD=doom1.wad CPU_HZ=25125000 LOWDETAIL=1`: build `doom.img` (the shareware WAD fits; the
  full 12 MB `doom.wad` does not fit the 8 MB PSRAM).
- `make flash`: write it to SPI flash; the menu's `doom` entry loads it.
- `make load`: upload over the UART instead (~17 s).

Keys (with `../load.py --attach --keys`): arrows move, Ctrl fire, space use, Shift run,
Alt strafe, Tab automap, Esc menu.
