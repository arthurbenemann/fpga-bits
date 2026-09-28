# Fixed BRAM entry point for the menu (which runs from PSRAM, see menu.c) to
# hand a UART command byte it already read back to boot.c, so that byte and
# whatever follows it (an upload) aren't lost. See boot.c's boot_entry() for
# what `cmd` (a0) means. Its address is written to boot_entry.h by the
# Makefile after linking, since it depends on how the linker lays out
# start.o ahead of it (see bram.ld: KEEP(start.o (.text)) KEEP(entry.o (.text))).
.equ IO_BASE, 0x400000
.section .text.entry   # named section, not just .text: see bram.ld's KEEP()
.globl entry
entry:
        li   gp, IO_BASE   # crt_psram.s already sets these for the menu; redone
        li   sp, 0x1800    # here so `entry` is a self-contained, documented ABI
        j    boot_entry
