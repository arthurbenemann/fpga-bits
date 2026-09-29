MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x1800  /* 6kB RAM */
}
SECTIONS
{
    everything :
    {
	. = ALIGN(4);
	KEEP(start.o (.text))
	KEEP(*(.text.entry))  /* psram's entry.s; a no-op when nothing defines it */
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.* .sdata .sdata.*)
        *(.sbss .sbss.* .bss .bss.* COMMON)
    } >BRAM
    /DISCARD/ : { *(.eh_frame .eh_frame_hdr) }
}
