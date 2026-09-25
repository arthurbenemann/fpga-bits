/* Programs loaded into PSRAM by the UART bootloader. One flat image starting
   at the entry point; .bss is included so objcopy zero-fills it. */
MEMORY
{
    PSRAM (RWX) : ORIGIN = 0x800000, LENGTH = 8M
}
SECTIONS
{
    image :
    {
        *crt_psram.o (.text)
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.* .sdata .sdata.*)
        *(.sbss .sbss.* .bss .bss.* COMMON)
        _end = .;               /* first free PSRAM byte */
    } >PSRAM
    /DISCARD/ : { *(.eh_frame .eh_frame_hdr) }
}
