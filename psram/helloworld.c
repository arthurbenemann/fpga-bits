/*
 Computes and displays the Mandelbrot set on the OLED display.
*/

#include <stdio.h>
#include <stdint.h>

#define IO_BASE 0x400000
#define IO_LEDS         4
#define IO_UART_DAT     8
#define IO_UART_CNTL    16
#define IO_COUNTER      32
#define IO_MANDEL_CTRL  64
#define IO_MANDEL_CR    128
#define IO_MANDEL_CI    256
#define IO_MANDEL_IT    512


#define IO_IN(port) *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

int main()
{
    for (;;)
    {
        printf("hellow\n");
    }
}
