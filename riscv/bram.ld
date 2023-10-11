MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x03FC  /* 1020B / 255 Words RAM */
}
SECTIONS
{
    everything :
    {
	. = ALIGN(4);
	start.o (.text)
        *(.*)
    } >BRAM
}
