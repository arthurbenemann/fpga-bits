// See fbcon.h. 8x8 glyphs 32..126, taken from the public-domain Linux console
// VGA8 font (kbd package); no libc used so plain (-nostdlib) programs can link it.
#include <stdint.h>
#include "fbcon.h"

#define IO_BASE      0x400000
#define IO_UART_DAT  (*(volatile uint32_t *)(IO_BASE + 8))
#define IO_UART_CNTL (*(volatile uint32_t *)(IO_BASE + 16))
#define IO_VIDEO     (*(volatile uint32_t *)(IO_BASE + 2048))  // {index<<16 | 0xRGB}
#define IO_GAME      (*(volatile uint32_t *)(IO_BASE + 4096))

#define IO_COUNTER   (*(volatile uint32_t *)(IO_BASE + 32))
#define IO_UART_RX   (*(volatile uint32_t *)(IO_BASE + 1024))

#define FB      ((volatile uint8_t *)0x200000)
#define FBW     320
#define FBH     200
#define COLS    40
#define ROWS    25

static const uint8_t font[95][8] = {
#include "font8x8.h"
};

static unsigned cur_row, cur_col, fg = 15, bg = 0;
static int attached;

static void glyph(unsigned row, unsigned col, int c)
{
    const uint8_t *g = (c >= 32 && c <= 126) ? font[c - 32] : font[0];
    volatile uint8_t *p = FB + row * 8 * FBW + col * 8;
    for (unsigned y = 0; y < 8; ++y, p += FBW)
        for (unsigned x = 0; x < 8; ++x)
            p[x] = (g[y] << x) & 0x80 ? fg : bg;
}

static void scroll(void)
{
    volatile uint8_t *p = FB;
    for (unsigned i = 0; i < (ROWS - 1) * 8 * FBW; ++i) p[i] = p[i + 8 * FBW];
    for (unsigned i = (ROWS - 1) * 8 * FBW; i < ROWS * 8 * FBW; ++i) p[i] = bg;
}

void con_setcolor(unsigned f, unsigned b) { fg = f; bg = b; }

void con_clear(void)
{
    volatile uint8_t *p = FB;
    for (unsigned i = 0; i < FBW * FBH; ++i) p[i] = bg;
    cur_row = cur_col = 0;
}

void con_init(void)
{
    IO_GAME = 0;
    IO_VIDEO = 0 << 16 | 0x000;
    IO_VIDEO = 15 << 16 | 0xFFF;
    fg = 15;
    bg = 0;
    con_clear();
}

void con_putc(int c)
{
    if (c == '\n') {
        cur_col = 0;
        ++cur_row;
    } else if (c == '\r') {
        cur_col = 0;
    } else if (c == '\b') {
        if (cur_col) { --cur_col; glyph(cur_row, cur_col, ' '); }
    } else {
        glyph(cur_row, cur_col, c);
        if (++cur_col == COLS) { cur_col = 0; ++cur_row; }
    }
    if (cur_row == ROWS) { scroll(); cur_row = ROWS - 1; }
}

void con_attach(void) { attached = 1; }

int putchar(int c)
{
    while (IO_UART_CNTL & (1u << 9));
    IO_UART_DAT = c;
    if (attached) con_putc(c);
    return c;
}

void con_at(unsigned col, unsigned row) { cur_col = col; cur_row = row; }

// Keyboard: load.py sends a press as the key's byte and a release as 0xF0, byte
// (--keys), or plain typed bytes with arrows as ESC [ A..D. Both come out as
// presses: releases are dropped, Doom's arrow codes and ESC sequences become
// K_*, Ctrl+letter gives the control code, Shift+letter the capital.
int con_key(void)
{
    static int skip, ctrl, shift;
    uint32_t c = IO_UART_RX;
    if (!(c & 0x100)) return -1;
    c &= 0xFF;
    if (skip) {
        skip = 0;
        if (c == 0xa3) ctrl = 0;
        if (c == 0xb6) shift = 0;
        return -1;
    }
    switch (c) {
    case 0xf0: skip = 1; return -1;
    case 0xa3: ctrl = 1; return -1;
    case 0xb6: shift = 1; return -1;
    case 0xb8: return -1;
    case 0xad: return K_UP;
    case 0xaf: return K_DOWN;
    case 0xac: return K_LEFT;
    case 0xae: return K_RIGHT;
    case 27: {                                  // reads pop the FIFO: read once per byte
        uint32_t t = IO_COUNTER, n;
        do n = IO_UART_RX; while (!(n & 0x100) && IO_COUNTER - t < 40000);
        if (!(n & 0x100) || (n & 0xFF) != '[') return 27;
        while (!((n = IO_UART_RX) & 0x100));
        c = n & 0xFF;
        return c == 'A' ? K_UP : c == 'B' ? K_DOWN : c == 'C' ? K_RIGHT : c == 'D' ? K_LEFT : -1;
    }
    }
    if (c == 10) return 13;
    if (c >= 'a' && c <= 'z') return ctrl ? c & 0x1f : shift ? c - 32 : c;
    return c;
}

int con_waitkey(void)
{
    int k;
    while ((k = con_key()) < 0);
    return k;
}
