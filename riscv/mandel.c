/*
 Computes and displays the Mandelbrot set over the UART, as ANSI colors.
 Keys: wasd or arrows move, +/- zoom, ,/. halve/double the iteration limit,
 h toggles hardware/software, r resets the view.
*/

int printf(const char *fmt, ...);
int putchar(int c);
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
#define IO_UART_RX      1024


#define IO_IN(port) *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)


// 256-step background palette, black -> blue -> red -> white, built at startup.
uint8_t palette[256][3];
const uint8_t stops[4][3] = {{0, 0, 0}, {0, 0, 240}, {240, 0, 0}, {255, 255, 255}};

void make_palette(void)
{
    for (int i = 0; i < 256; ++i) {
        int seg = i * 3 >> 8, f = i * 3 & 255;
        for (int c = 0; c < 3; ++c)
            palette[i][c] = stops[seg][c] + ((stops[seg + 1][c] - stops[seg][c]) * f >> 8);
    }
}

// Decimal 0..255 without division (rv32i has none).
void put_u8(int v)
{
    int h = 0, t = 0;
    while (v >= 100) { v -= 100; ++h; }
    while (v >= 10)  { v -= 10;  ++t; }
    if (h) putchar('0' + h);
    if (h || t) putchar('0' + t);
    putchar('0' + v);
}

// Two character cells of palette color i (-1: black, inside the set).
void put_color(int i)
{
    const uint8_t *rgb = i < 0 ? stops[0] : palette[i];
    printf("\033[48;2;");
    put_u8(rgb[0]); putchar(';');
    put_u8(rgb[1]); putchar(';');
    put_u8(rgb[2]); printf("m  ");
}

#define mandel_shift 27  // Q4.27, as in the accelerator
#define mandel_mul (1 << mandel_shift)
#define norm_max (4 << mandel_shift)

// For 400x300 screen
// it=10,   379917 kcycles
// it=100, 1272175 kcycles

int mandel_SW(int Cr, int Ci, int iter){ 
    // Main cardioid and period-2 bulb never escape: same check as the accelerator.
    if (Cr >= -2 * mandel_mul && Cr < 2 * mandel_mul && Ci >= -2 * mandel_mul && Ci < 2 * mandel_mul) {
        int64_t a = Cr - mandel_mul / 4, b = Cr + mandel_mul;
        int64_t y2 = (int64_t)Ci * Ci >> mandel_shift;
        int64_t q = (a * a >> mandel_shift) + y2;
        if (q * (q + a) <= y2 << (mandel_shift - 2) || (b * b >> mandel_shift) + y2 <= mandel_mul / 16)
            return 0;
    }
    int Zr = Cr;
    int Zi = Ci;
    while (iter > 0){
        int Zrr = ((int64_t)Zr * Zr) >> mandel_shift;
        int Zii = ((int64_t)Zi * Zi) >> mandel_shift;
        int Zri = ((int64_t)Zr * Zi) >> (mandel_shift - 1);
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

// The key received, or -1 if none. Only the latest byte is kept, so an arrow
// key's ESC [ prefix is often gone: A-D alone also count as arrows.
int getkey(void)
{
    uint32_t c = IO_IN(IO_UART_RX);
    return c & 0x100 ? c & 0xFF : -1;
}

#define W 80
#define H 60
#define STEP0 (3 * mandel_mul / H)  // C units per character, unzoomed
int main()
{
    uint32_t start,end,t,compute; // timing variables

    int cx = -mandel_mul / 2, cy = 0;   // view centre
    int step = STEP0;                   // C units per character
    int max_it = 64;
    int sw = 0;                         // compute in software instead of the accelerator

    make_palette();
    printf("\033[2J");
    for (;;)
    {
        start = IO_IN(IO_COUNTER);
        compute = 0;
        IO_OUT(IO_MANDEL_IT, max_it);

        int key = -1;
        int last_color = -2;
        int ps = 0;                     // the gradient spans min(max_it, 256) iterations
        while ((1 << ps) < max_it && ps < 8) ++ps;
        printf("\033[H");
        int Ci = cy - step * H / 2;
        for (int Y = 0; Y < H && key < 0; ++Y)  // a key restarts the frame
        {
            int Cr = cx - step * W / 2;
            for (int X = 0; X < W; ++X)
            {
                t = IO_IN(IO_COUNTER);
                int left = sw ? mandel_SW(Cr,Ci,max_it) : mandel_HW(Cr,Ci);  // 0: in the set
                int color = (max_it - left) << (8 - ps) & 511;    // then runs back down
                color = !left ? -1 : color > 255 ? 511 - color : color;
                compute += IO_IN(IO_COUNTER) - t;
                if (color == last_color) printf("  "); else put_color(color);
                last_color = color;
                Cr += step;
            }
            Ci += step;

            printf("\033[49m\r\n");
            last_color = -2;
            key = getkey();
        }
        end = IO_IN(IO_COUNTER);
        if (key < 0) printf("%d kcycles (%d compute), zoom %dx, max it %d, %s  [wasd/arrows move, +/- zoom, ,/. iterations, h hw/sw, r reset]\033[K",
               (end-start)>>10, compute>>10, STEP0 / step, max_it, sw ? "SW" : "HW");

        // Wait for a key, then apply it and any that came in meanwhile.
        while (key < 0) key = getkey();
        for (; key >= 0; key = getkey())
        {
            switch (key) {
            case 'w': case 'A': cy -= 8 * step; break;
            case 's': case 'B': cy += 8 * step; break;
            case 'd': case 'C': cx += 8 * step; break;
            case 'a': case 'D': cx -= 8 * step; break;
            case '+': case '=': step = step * 3 / 4; if (step < 1) step = 1; break;
            case '-': case '_': step = step * 4 / 3 + 1; if (step > 2 * STEP0) step = 2 * STEP0; break;
            case '.': case '>': if (max_it < 16384) max_it *= 2; break;
            case ',': case '<': if (max_it > 1) max_it /= 2; break;
            case 'h': sw = !sw; break;
            case 'r': cx = -mandel_mul / 2; cy = 0; step = STEP0; max_it = 64; break;
            }
        }
    }
}
