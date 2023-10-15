/*
 Computes and displays the Mandelbrot set on the OLED display.
*/

#include <stdio.h>
#include <stdint.h>

#define IO_BASE 0x400000
#define IO_LEDS 4
#define IO_UART_DAT   8
#define IO_UART_CNTL  16
#define IO_COUNTER 32

#define IO_IN(port) *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define W 300
#define H 200

#define ANSIRGB(R, G, B) "\033[48;2;" #R ";" #G ";" #B "m  "

const char *colormap[21] = {
    ANSIRGB(  0,   0,   0),
    ANSIRGB(250, 250, 250),
    ANSIRGB(220, 200, 240),
    ANSIRGB(200, 180, 230),
    ANSIRGB(180, 160, 220),
    ANSIRGB(160, 140, 210),
    ANSIRGB(140, 120, 200),

    ANSIRGB(100, 100, 190),
    ANSIRGB( 80,  80, 180),
    ANSIRGB( 60,  60, 170),
    ANSIRGB( 40,  40, 160),
    ANSIRGB( 30,  30, 150),
    ANSIRGB( 20,  20, 140),
    ANSIRGB( 10,  10, 130),

    ANSIRGB(  0,   0, 120),
    ANSIRGB(  0,   0, 100),
    ANSIRGB(  0,   0,  80),
    ANSIRGB(  0,   0,  60),
    ANSIRGB(  0,   0,  40),
    ANSIRGB(  0,   0,  20),
    ANSIRGB(  0,   0,   0)
    };

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define norm_max (4 << mandel_shift)

int mandel(int Cr, int Ci){ // 23308ms at it=10
    int iter = 10;
    int Zr = Cr;
    int Zi = Ci;
    while (iter > 0){
        int Zrr = (Zr * Zr) >> mandel_shift;
        int Zii = (Zi * Zi) >> mandel_shift;
        int Zri = (Zr * Zi) >> (mandel_shift - 1);
        Zr = Zrr - Zii + Cr;
        Zi = Zri + Ci;
        if (Zrr + Zii > norm_max){
            break;
        }
        --iter;
    }
    return iter;
}

int main()
{
    uint32_t start,end; // timing variables

    int xmin= -2 * mandel_mul;
    int ymin= -2 * mandel_mul;
    int xmax=  1 * mandel_mul;
    int ymax=  2 * mandel_mul;
    for (;;)
    {
        int dx  = (xmax - xmin) / H;
        int dy  = (ymax - ymin) / H;
        
        start = IO_IN(IO_COUNTER);

        int last_color = -1;
        printf("\033[H");
        int Ci = ymin;
        for (int Y = 0; Y < H; ++Y)
        {
            int Cr = xmin;
            for (int X = 0; X < W; ++X)
            {
                int color = mandel(Cr,Ci);
                printf(color == last_color ? "  " : colormap[color]);
                last_color = color;
                Cr += dx;
            }
            Ci += dy;

            printf("\033[49m\n");
            last_color = -1;
        }
        end = IO_IN(IO_COUNTER);
        printf("%d kcycles", (end-start)>>20); 

        xmax = xmin + (xmax-xmin)/2;
        ymax = ymax/2;
        ymin = -ymax;
    }
}
