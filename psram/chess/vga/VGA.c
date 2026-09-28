// VGA.c -- replaces the dsPIC SPI/DMA/ISR video generator with a shim onto
// this SoC's 320x200 8bpp HDMI framebuffer (0x200000) + palette (IO
// 0x400800, {index<<16|0xRGB}). graphics.c (plotDot/plotLine/plotSquare/
// plotCircle/readDotA/readDotH) and text.c (putV/putsV) are unchanged and
// poke VH/VA directly using VGA.h's constants -- this file only owns the
// buffer storage and the init/clear/swap entry points, plus a tick source
// for chessInterface.c's cursor blink (see VGA.h).
//
// No real double buffering: nothing scans VH/VA out but swapV() itself (our
// "vsync" IS the blit), so VA and VH are the same buffer -- draw calls
// between one swapV() and the next are invisible until the blit runs, same
// end result as the original hidden/active swap without needing a second
// buffer or a wait-for-vsync.
#include "VGA.h"
#include <stdint.h>

static int VBuf[VRES * lineSize];
volatile int *VH = VBuf;
volatile int *VA = VBuf;

#ifdef HOST
#include <stdio.h>
#include <time.h>
unsigned long now_ticks(void) { return (unsigned long)clock(); }
void initVGA(void) { cleanHScreen(); }
void cleanHScreen(void) { for (unsigned i = 0; i < VRES * lineSize; ++i) VBuf[i] = 0; }
// Host "display": write the monochrome buffer out as a PGM image (fixed
// path, overwritten every frame) so the board, cursor, promotion box etc.
// can actually be looked at without real hardware.
void swapV(void)
{
    FILE *f = fopen("/tmp/chess_host.pgm", "wb");
    if (!f) return;
    fprintf(f, "P5\n%u %u\n255\n", (unsigned)HRES, (unsigned)VRES);
    for (unsigned y = 0; y < VRES; ++y)
        for (unsigned x = 0; x < HRES; ++x) {
            int bit = VH[y * lineSize + (x >> 4)] & (0x8000 >> (x & 0xF));
            fputc(bit ? 255 : 0, f);
        }
    fclose(f);
}
#else
#define IO_BASE     0x400000
#define IO_COUNTER  (*(volatile uint32_t *)(IO_BASE + 32))
#define IO_VIDEO    (*(volatile uint32_t *)(IO_BASE + 2048))   // {index<<16|0xRGB}
#define IO_GAME     (*(volatile uint32_t *)(IO_BASE + 4096))
#define FB          ((volatile uint8_t *)0x200000)
#define FBW         320
#define FBH         200

// Old GUI's monochrome ink/paper, as two palette entries.
#define COL_PAPER   0
#define COL_INK     1

// 200x150 fits inside 320x200 only at 1x (2x would be 400x300) -- centre it.
// 1:1, centred (2:1 would be 400x300, bigger than the framebuffer).
#define OX  ((FBW - HRES) / 2)
#define OY  ((FBH - VRES) / 2)

unsigned long now_ticks(void) { return IO_COUNTER >> 8; }   // ~ dsPIC's 1:256 prescaled TMR1

void initVGA(void)
{
    IO_GAME = 0;                       // keep game mode off (plain framebuffer)
    IO_VIDEO = COL_PAPER << 16 | 0x000; // black paper
    IO_VIDEO = COL_INK   << 16 | 0xFFF; // white ink
    for (unsigned i = 0; i < FBW * FBH; ++i) FB[i] = COL_PAPER;   // the menu's text is still there
    cleanHScreen();
}

void cleanHScreen(void)
{
    for (unsigned i = 0; i < VRES * lineSize; ++i) VBuf[i] = 0;
}

void swapV(void)
{
    for (unsigned y = 0; y < VRES; ++y) {
        volatile int *row = VH + y * lineSize;
        volatile uint8_t *out = FB + (OY + y) * FBW + OX;
        for (unsigned x = 0; x < HRES; ++x)
            out[x] = row[x >> 4] & (0x8000 >> (x & 0xF)) ? COL_INK : COL_PAPER;
    }
}
#endif
