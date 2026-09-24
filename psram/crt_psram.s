# Entry point for programs loaded into PSRAM by the bootloader (linked first by psram.ld).
.section .text
.globl _start
_start:
    li   gp, 0x400000   # IO base: putchar.s addresses IO relative to gp
    li   sp, 0x1800     # stack at the top of BRAM
    call main
    li   t0, 0          # main returned: restart the bootloader
    jr   t0
