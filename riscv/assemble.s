# Simple blinker

.equ IO_BASE, 0x400000  
# IO-reg offsets. To read or write one of them,
# use IO_XXX(gp)
.equ IO_LEDS, 4
.equ IO_UART_DAT, 8
.equ IO_UART_CNTL, 16

.section .text

.globl _start

_start:
    li   gp,IO_BASE
	li   sp,0x1800
	call main
	ebreak

main:
.L0:
	la   a0, hello
	call putstring
	ebreak
	j .L0

putstring:
	addi sp,sp,-4 # save ra on the stack
	sw ra,0(sp)   # (need to do that for functions that call functions)
	mv t2,a0	
.L1:    lbu a0,0(t2)
	beqz a0,.L2
	call putchar
	addi t2,t2,1	
	j .L1
.L2:    lw ra,0(sp)  # restore ra
	addi sp,sp,4 # restore sp
	ret



putchar:
   sw a0, IO_UART_DAT(gp)
   li t0, 1<<9
.L0char:  
   lw t1, IO_UART_CNTL(gp)
   and t1, t1, t0
   bnez t1, .L0char
  ret

hello:
	.asciz "\nHello, world !\n"
