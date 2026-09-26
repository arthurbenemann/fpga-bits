# PSRAM SoC

RISC-V at 12 MHz with 8 MB PSRAM (PMOD-PSRAM-SDCARD on PMOD 1A) and a UART bootloader in BRAM.

- `make soc-prog`: flash once.
- `make load IMG=mandel.img` (or `memtest.img`, `coremark.img`): upload one program and run it.
- `make bundle`: store all three in the top 1 MB of PSRAM. Keys `1`-`3` in the boot menu run one, and any other key lists them again. The bundle survives the reset button and program exits, but not a power-off.
- To get back to the menu, press `q` in mandel, press any key in memtest (it stops after the current pass), or press the iCEBreaker user button (reset).
- Terminal: `picocom -b 3000000 /dev/ttyUSB1` (the UART is the FT2232H's second port).
