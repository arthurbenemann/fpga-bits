/*
 Mandelbrot set on the 320x200 DVI framebuffer (shown 2x2 on 640x480), using
 the hardware accelerator at IO_MANDEL_*. Same controls as riscv/mandel.c's
 UART/ASCII version: wasd or arrows pan, +/- zoom, ,/. halve/double the
 iteration limit, r resets the view, q returns to the bootloader/menu. A
 short status line (centre, zoom, iterations, render time) goes to the UART;
 the picture only goes to the framebuffer.
*/
int printf(const char *fmt, ...);
#include <stdint.h>
#include "fbcon.h"

#define IO_BASE        0x400000
#define IO_COUNTER     32
#define IO_MANDEL_CTRL 64
#define IO_MANDEL_CR   128
#define IO_MANDEL_CI   256
#define IO_MANDEL_IT   512
#define IO_UART_RX     1024
#define IO_VIDEO       2048   // W palette entry {index << 16 | 0xRGB}
#define IO_GAME        4096   // W {front_req, game_mode}: Doom's double-buffer mode

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define W  320
#define H  200
#define FB 0x200000
#define fb8 ((volatile uint8_t *)FB)

// 256-step background gradient (Wikipedia's classic Mandelbrot colours),
// folded below for a cyclic look at any iteration limit. Index 0 and 15 are
// left out of the upload so a text console can use them; fb bytes never
// take those two values either.
uint8_t palette[256][3];
#define NSTOPS 6
const uint8_t stops[NSTOPS][3] = {
    {0, 0, 0}, {0, 7, 100}, {32, 107, 203}, {237, 255, 255}, {255, 170, 0}, {0, 2, 0}
};

void make_palette(void)
{
    for (int i = 0; i < 256; ++i) {
        int seg = i * (NSTOPS - 1) >> 8, f = i * (NSTOPS - 1) & 255;
        for (int c = 0; c < 3; ++c)
            palette[i][c] = stops[seg][c] + ((stops[seg + 1][c] - stops[seg][c]) * f >> 8);
    }
    palette[1][0] = palette[1][1] = palette[1][2] = 0;   // fb value 1: pure black interior
}

void upload_palette(void)
{
    for (int i = 1; i < 256; ++i) {
        if (i == 15) continue;
        int r = palette[i][0] >> 4, g = palette[i][1] >> 4, b = palette[i][2] >> 4;
        IO_OUT(IO_VIDEO, i << 16 | r << 8 | g << 4 | b);
    }
}

// Software Mandelbrot in Q4.12 (the accelerator hangs at 25 MHz): 16-bit operands, so
// every product fits the 32-bit mul; zoom is limited to about 45x.
#define mandel_shift 12
#define ONE (1 << mandel_shift)

// Iterations left (0: in the set), like the accelerator returned.
static int hw;   // 'h': the IO_MANDEL accelerator (Q4.27), unreliable when overclocked

int mandel_HW(int cr, int ci, int max_it)
{
    if (hw) {
        IO_OUT(IO_MANDEL_CR, cr << 15);
        IO_OUT(IO_MANDEL_CI, ci << 15);
        IO_OUT(IO_MANDEL_CTRL, 0);
        for (int t = 0; !IO_IN(IO_MANDEL_CTRL); )
            if (++t > 100000) return 0;       // hung: count the point as in the set
        return IO_IN(IO_MANDEL_IT);
    }
    int x = 0, y = 0, n = max_it;
    while (n) {
        int xx = x * x >> mandel_shift, yy = y * y >> mandel_shift;
        if (xx + yy > 4 * ONE) return n;
        y = (x * y >> (mandel_shift - 1)) + ci;
        x = xx - yy + cr;
        --n;
    }
    return 0;
}

#define getkey con_key

#define STEP0 (7 * ONE / (2 * W))    // 3.5 wide over 320 px, unzoomed
#define CX0   (-3 * (ONE / 4))       // classic full view, real -2.5..1.0

int main()
{
    IO_OUT(IO_GAME, 0);      // make sure Doom's game mode is off
    make_palette();
    upload_palette();

    int cx = CX0, cy = 0;    // view centre, Q4.27
    int step = STEP0;        // C units per pixel
    int max_it = 64;

    printf("\r\nMandelbrot is on the HDMI display. Keys: arrows/wasd pan, +/- zoom, ,/. iterations, r reset, q menu\r\n");
    for (;;) {
        uint32_t start = IO_IN(IO_COUNTER);
        IO_OUT(IO_MANDEL_IT, max_it);
        int ps = 0;                          // the gradient spans min(max_it, 256) iterations
        while ((1 << ps) < max_it && ps < 8) ++ps;

        int key = -1;
        int Ci = cy - step * H / 2;
        for (int y = 0; y < H && key < 0; ++y, Ci += step) {
            int Cr = cx - step * W / 2;
            for (int x = 0; x < W; ++x, Cr += step) {
                int left = mandel_HW(Cr, Ci, max_it);
                int fbval;
                if (!left) {
                    fbval = 1;
                } else {
                    int c = (max_it - left) << (8 - ps) & 511;   // then runs back down
                    c = c > 255 ? 511 - c : c;
                    fbval = c == 0 ? 2 : c == 15 ? 14 : c;        // keep 0 and 15 out of the fb
                }
                fb8[y * W + x] = fbval;
            }
            key = getkey();   // a key aborts and restarts the frame, like the UART version
        }
        uint32_t ms = (IO_IN(IO_COUNTER) - start) / (CPU_HZ / 1000);
        if (key < 0)
            printf("centre %d,%d  zoom %d%%  iterations %d  %d ms  %s  [+/- or z/x zoom, ,/. iterations, h hw/sw]"
                   "\r\n",
                   cx, cy, 100 * STEP0 / step, max_it, ms, hw ? "HW" : "SW");

        while (key < 0) key = getkey();
        for (; key >= 0; key = getkey()) {
            switch (key) {
            case 'w': case K_UP: cy -= 8 * step; break;
            case 's': case K_DOWN: cy += 8 * step; break;
            case 'd': case K_RIGHT: cx += 8 * step; break;
            case 'a': case K_LEFT: cx -= 8 * step; break;
            case '+': case '=': case 'z': step = step * 3 / 4; if (step < 1) step = 1; break;
            case '-': case '_': case 'x': step = step * 4 / 3 + 1; if (step > 2 * STEP0) step = 2 * STEP0; break;
            case '.': case '>': if (max_it < 16384) max_it *= 2; break;
            case ',': case '<': if (max_it > 1) max_it /= 2; break;
            case 'r': cx = CX0; cy = 0; step = STEP0; max_it = 64; break;
            case 'h': hw = !hw; break;
            case 27: case 'q': printf("\r\n"); return 0;
            }
        }
    }
}
