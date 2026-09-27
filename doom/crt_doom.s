# Entry point for Doom in PSRAM (doom.ld links it first).
.section .text
.globl _start
_start:
    li   gp, 0x400000   # IO base
    la   sp, _stack_top
    la   tp, __tls_base # picolibc keeps errno in TLS
    call main
    li   t0, 0          # main returned: restart the bootloader
    jr   t0
