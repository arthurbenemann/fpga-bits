# The IWAD, linked at WAD_ADDR (doom.ld) and read in place by dg_uart.c.
.section .wad, "a"
.incbin WAD_FILE
