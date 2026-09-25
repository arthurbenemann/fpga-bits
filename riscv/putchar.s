# Base address of memory-mapped IO,
# Loaded into gp at startup
.equ IO_BASE, 0x400000  

# IO-reg offsets. To read or write one of them,
# use IO_XXX(gp)
.equ IO_LEDS, 4
.equ IO_UART_DAT, 8
.equ IO_UART_CNTL, 16

.section .text
.globl putchar

# Waits for the previous byte to go out, then starts this one and returns,
# so the caller's work overlaps the transmission.
putchar:
   li t0, 1<<9
.L0:  
   lw t1, IO_UART_CNTL(gp)
   and t1, t1, t0
   bnez t1, .L0
   sw a0, IO_UART_DAT(gp)
  ret
  