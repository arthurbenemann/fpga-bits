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


#define ANSIRGB(R, G, B) "\033[48;2;" #R ";" #G ";" #B "m  "

const char *colormap[32] = {
    ANSIRGB(  0,   0,   0),     // Black -1

    ANSIRGB(255, 255, 255),     // White - 6
    ANSIRGB(240, 200, 200),
    ANSIRGB(240, 160, 160),
    ANSIRGB(240, 120, 120),
    ANSIRGB(240,  80,  80),
    ANSIRGB(240,  40,  40),

    ANSIRGB(240,   0,   0),     // Red -12
    ANSIRGB(220,   0,  20),
    ANSIRGB(200,   0,  40),
    ANSIRGB(180,   0,  60),
    ANSIRGB(160,   0,  80),
    ANSIRGB(140,   0, 100),
    ANSIRGB(120,   0, 120),
    ANSIRGB(100,   0, 140),
    ANSIRGB( 80,   0, 160),
    ANSIRGB( 60,   0, 180),
    ANSIRGB( 40,   0, 200),
    ANSIRGB( 20,   0, 220),


    ANSIRGB(  0,   0, 240),     // Blue -12
    ANSIRGB(  0,   0, 220),
    ANSIRGB(  0,   0, 200),
    ANSIRGB(  0,   0, 180),
    ANSIRGB(  0,   0, 160),
    ANSIRGB(  0,   0, 140),
    ANSIRGB(  0,   0, 120),
    ANSIRGB(  0,   0, 100),
    ANSIRGB(  0,   0,  80),
    ANSIRGB(  0,   0,  60),
    ANSIRGB(  0,   0,  40),
    ANSIRGB(  0,   0,  20),

    ANSIRGB(  0,   0,   0)      // Black -1
    };

#define mandel_shift 10
#define mandel_mul (1 << mandel_shift)
#define norm_max (4 << mandel_shift)

// For 400x300 screen
// it=10,   379917 kcycles
// it=100, 1272175 kcycles

int mandel_SW(int Cr, int Ci){ 
    int iter = 100;
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

// For 400x300 screen
// it=10,  59120 kcycles
// it=100, 75072 kcycles
int mandel_HW(int Cr, int Ci){ 
    //printf("run mandel\n");
    IO_OUT(IO_MANDEL_CR,Cr);
    IO_OUT(IO_MANDEL_CI,Ci);
    IO_OUT(IO_MANDEL_CTRL,0);
    //printf("IO CTRL %x %x\n",Cr,Ci);
    while (!IO_IN(IO_MANDEL_CTRL));
    int it = IO_IN(IO_MANDEL_IT);
    //printf("done, %x %x it=%d\n",Cr,Ci,it);
    return it;
}

#define W 800
#define H 600
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
                int color = mandel_HW(Cr,Ci)%32;
                printf(color == last_color ? "  " : colormap[color]);
                last_color = color;
                Cr += dx;
            }
            Ci += dy;

            printf("\033[49m\n");
            last_color = -1;
        }
        end = IO_IN(IO_COUNTER);
        printf("%d kcycles", (end-start)>>10); 

        xmax = xmin + (xmax-xmin)/2;
        ymax = ymax/2;
        ymin = -ymax;
    }
}
