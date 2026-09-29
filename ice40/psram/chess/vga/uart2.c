// uart2.c -- UART2.h on this SoC's UART registers (see fbcon.c/pi.c for the
// same pattern). Used by chessInterface.c to echo moves as text over the
// serial link, same as the original.
#include <stdint.h>

#ifdef HOST
#include <stdio.h>
void initU2(void) { }
void putU2(int c) { putchar(c); }
void putsU2(char *s) { fputs(s, stdout); }
char getU2(void) { int c = getchar(); return c == EOF ? 0 : (char)c; }
#else
#define IO_BASE      0x400000
#define IO_UART_DAT  (*(volatile uint32_t *)(IO_BASE + 8))
#define IO_UART_CNTL (*(volatile uint32_t *)(IO_BASE + 16))
#define IO_UART_RX   (*(volatile uint32_t *)(IO_BASE + 1024))

void initU2(void) { }

void putU2(int c)
{
    while (IO_UART_CNTL & (1u << 9));   // wait while the TX FIFO is full
    IO_UART_DAT = c;
}

void putsU2(char *s) { while (*s) putU2(*s++); }

char getU2(void)
{
    uint32_t c;
    while (!((c = IO_UART_RX) & 0x100));
    return (char)(c & 0xFF);
}
#endif
