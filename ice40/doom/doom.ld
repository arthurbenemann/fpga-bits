/* Doom image in PSRAM: program at 0x800000, malloc heap up to the IWAD, the
   IWAD at WAD_ADDR, then the zone up to the top of PSRAM. The Makefile defines
   WAD_ADDR and _stack_top. */
ENTRY(_start)
SECTIONS
{
    image 0x800000 :
    {
        KEEP(*crt_doom.o (.text))
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.* .sdata .sdata.*)
        *(.tdata .tdata.*)      /* errno: 'image' becomes the TLS segment */
        *(.tbss .tbss.*)
        *(.sbss .sbss.* .bss .bss.* COMMON)
        _end = .;
    }
    .wad WAD_ADDR : { _wad = .; KEEP(*(.wad)) _wad_end = .; }
    __tls_base   = ADDR(image);
    __heap_start = ALIGN(_end, 16);
    __heap_end   = _wad;
    _zone        = ALIGN(_wad_end, 16);
    _zone_end    = 0x1000000;
    ASSERT(_end <= WAD_ADDR, "program overlaps the WAD: raise WAD_ADDR")
    /DISCARD/ : { *(.eh_frame .eh_frame_hdr .comment) }
}
