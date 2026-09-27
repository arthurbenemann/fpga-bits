// doomgeneric platform layer for the iCEBreaker PSRAM SoC: the DVI framebuffer
// (or TEXT=1: UART text output),
// keys from UART_RX, time from COUNTER, IWAD and zone in PSRAM (doom.ld), and
// the few libc system hooks picolibc needs. No files: fopen always fails.
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "doomgeneric.h"
#include "doomkeys.h"
#include "doomstat.h"
#include "i_video.h"
#include "m_argv.h"
#include "m_menu.h"
#include "r_main.h"
#include "r_state.h"
#include "tables.h"
#include "w_file.h"
#include "z_zone.h"

#define IO(off) (*(volatile uint32_t *)(0x400000 + (off)))
#define UART_DAT 0x8
#define UART_CNTL 0x10
#define COUNTER 0x20
#define UART_RX 0x400
#define VIDEO 0x800     // W palette entry {index << 16 | 0xRGB}, R frames shown
#define FB ((byte *)0x200000)

#ifndef DOOM_ARGS
#define DOOM_ARGS
#endif
#ifndef COLS
#define COLS 80        // text grid for the picture (the status line takes a row)
#define ROWS 25
#endif
#ifndef BLOCKS
#define BLOCKS 10       // view size 3..11 (10: full width with status bar)
#endif
#ifndef TEXT
#define TEXT 0          // 1: draw on the UART as text instead of the framebuffer
#endif
#ifndef COLOR
#define COLOR 0         // 1: tint characters with the 8 bright ANSI colours
#endif
#ifndef LOWDETAIL
#define LOWDETAIL 0     // 1: half horizontal resolution
#endif

// ---- UART: RX bytes are also collected while waiting to send, since the
// receive register holds only one byte.
static uint8_t rxq[64];
static unsigned rx_in, rx_out;

static void rx_poll(void)
{
    uint32_t c = IO(UART_RX);
    if ((c & 0x100) && rx_in - rx_out < sizeof rxq) rxq[rx_in++ % sizeof rxq] = c;
}

static void tx(int c)
{
    while (IO(UART_CNTL) & (1 << 9)) rx_poll();
    IO(UART_DAT) = c;
}

static int put(char c, FILE *f)
{
    (void)f;
    if (c == '\n') tx('\r');
    tx(c);
    return (uint8_t)c;
}

static int get(FILE *f)
{
    (void)f;
    while (rx_in == rx_out) rx_poll();
    return rxq[rx_out++ % sizeof rxq];
}

static FILE uart = FDEV_SETUP_STREAM(put, get, NULL, _FDEV_SETUP_RW);
FILE *const stdin = &uart, *const stdout = &uart, *const stderr = &uart;

// ---- libc hooks
int open(const char *p, int f, ...) { (void)p; (void)f; errno = ENOENT; return -1; }
int close(int fd) { (void)fd; return -1; }
int read(int fd, void *b, size_t n) { (void)fd; (void)b; (void)n; return -1; }
int write(int fd, const void *b, size_t n) { (void)fd; (void)b; return n; }
long lseek(int fd, long o, int w) { (void)fd; (void)o; (void)w; return -1; }
int unlink(const char *p) { (void)p; return -1; }
int rename(const char *a, const char *b) { (void)a; (void)b; return -1; }
int mkdir(const char *p, int m) { (void)p; (void)m; return -1; }
void _exit(int s)
{
    (void)s;
    while (IO(UART_CNTL) & (1 << 9));
    ((void (*)(void))0)();      // back to the bootloader
    for (;;);
}

// ---- time: COUNTER is a free-running 32-bit counter at the CPU clock (CPU_HZ).
#define TICKS_MS (CPU_HZ / 1000)
uint32_t DG_GetTicksMs(void)
{
    static uint32_t last, rem, ms;
    uint32_t now = IO(COUNTER);
    rem += now - last;
    last = now;
    ms += rem / TICKS_MS;
    rem %= TICKS_MS;
    return ms;
}

void DG_SleepMs(uint32_t ms)
{
    uint32_t t0 = IO(COUNTER);
    while (IO(COUNTER) - t0 < ms * TICKS_MS) rx_poll();
}

// ---- IWAD: linked at WAD_ADDR, used in place (lumps are not copied). Any
// "*.wad" opens it; other files (e.g. a demo .lmp) do not exist.
extern uint8_t _wad[], _wad_end[], _zone[], _zone_end[];

bool M_FileExists(char *name) { return strstr(name, ".wad") != NULL; }   // replaces m_misc.c's
static wad_file_t *mem_open(char *path);
static void mem_close(wad_file_t *w) { (void)w; }
static size_t mem_read(wad_file_t *w, unsigned off, void *buf, size_t n)
{
    if (off >= w->length) return 0;
    if (n > w->length - off) n = w->length - off;
    memcpy(buf, w->mapped + off, n);
    return n;
}
wad_file_class_t stdc_wad_file = { mem_open, mem_close, mem_read };
static wad_file_t wad = { &stdc_wad_file };

static wad_file_t *mem_open(char *path)
{
    if (!M_FileExists(path)) return NULL;
    wad.mapped = _wad;
    wad.length = _wad_end - _wad;
    return &wad;
}

// Replace i_system.c's versions (weakened in the Makefile); its I_Error spins
// forever, this one returns to the bootloader.
void I_Error(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vprintf(fmt, ap);
    va_end(ap);
    printf("\n");
    _exit(1);
}

byte *I_ZoneBase(int *size)
{
    int p = M_CheckParmWithArgs("-kb", 1);      // cap the zone, to find the minimum
    *size = p ? atoi(myargv[p + 1]) << 10 : _zone_end - _zone;
    printf("zone: %p, %d KB\n", _zone, *size >> 10);
    return _zone;
}

// ---- keys: a terminal sends only presses, so each key is released after
// HOLD_MS unless it repeats. WASD move, f fires, space uses, q/e strafe.
#define HOLD_MS 150
static uint32_t held[256];
static uint16_t evq[64];        // key, | 0x100 when pressed
static int ev_n, ev_i;

static int doomkey(int c)
{
    switch (c) {
    case 'w': return KEY_UPARROW;
    case 's': return KEY_DOWNARROW;
    case 'a': return KEY_LEFTARROW;
    case 'd': return KEY_RIGHTARROW;
    case 'q': return KEY_STRAFE_L;
    case 'e': return KEY_STRAFE_R;
    case 'f': return KEY_FIRE;
    case ' ': return KEY_USE;
    case '\r': case '\n': return KEY_ENTER;
    case 0x1b: return KEY_ESCAPE;
    case 0x7f: case 8: return KEY_BACKSPACE;
    default: return c >= 'A' && c <= 'Z' ? c + 32 : c;
    }
}

void DG_ReadInput(void)
{
    uint32_t now = DG_GetTicksMs();
    ev_n = ev_i = 0;
    rx_poll();
    while (rx_in != rx_out && ev_n < 60) {
        int k = doomkey(rxq[rx_out++ % sizeof rxq]);
        if (!held[k]) evq[ev_n++] = 0x100 | k;
        held[k] = now | 1;
    }
    for (int k = 1; k < 256 && ev_n < 64; k++)
        if (held[k] && now - held[k] > HOLD_MS) { held[k] = 0; evq[ev_n++] = k; }
}

int DG_GetKey(int *pressed, unsigned char *key)
{
    if (ev_i == ev_n) return 0;
    *pressed = evq[ev_i] >> 8;
    *key = evq[ev_i++];
    return 1;
}

// ---- video: replaces i_video.c's I_InitGraphics/I_SetPalette/I_FinishUpdate
// (weakened in the Makefile). Doom draws its 320x200 palettized screen
// (I_VideoBuffer) straight into the framebuffer, which the hardware shows.
void I_InitGraphics(void)
{
    extern int I_InitInput(void);
    I_VideoBuffer = TEXT ? Z_Malloc(SCREENWIDTH * SCREENHEIGHT, PU_STATIC, NULL) : FB;
    screenvisible = true;
    I_InitInput();
}

#if !TEXT
void I_SetPalette(byte *pal)
{
    const byte *g = gammatable[usegamma];
    for (int i = 0; i < 256; i++, pal += 3)
        IO(VIDEO) = i << 16 | (g[pal[0]] >> 4) << 8 | (g[pal[1]] >> 4) << 4 | g[pal[2]] >> 4;
}

// Frames per second on the UART, every 64 frames drawn.
void I_FinishUpdate(void)
{
    static uint32_t n, t0;
    if (++n % 64) return;
    uint32_t t = DG_GetTicksMs();
    printf("\r%d.%d fps ", 640000 / (t - t0) / 10, 640000 / (t - t0) % 10);
    t0 = t;
}
#else
// Each of COLSxROWS characters samples two pixels of the 320x200 palettized
// screen, brightness through a ramp.
static const char ramp[] = " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";
static uint8_t luma[256];       // palette index -> 0..255
static char tint[256];          // palette index -> ANSI colour digit: bit 0 red, 1 green, 2 blue

// The tint is the hue only (brightness is the character): each channel within
// 3/4 of the brightest one counts, so greys come out white.
void I_SetPalette(byte *pal)
{
    for (int i = 0; i < 256; i++, pal += 3) {
        const byte *g = gammatable[usegamma];
        int r = g[pal[0]], gr = g[pal[1]], b = g[pal[2]];
        int m = (r > gr ? r : gr) > b ? (r > gr ? r : gr) : b;
        luma[i] = (r + gr + b) * 85 >> 8;
        tint[i] = '0' + (4 * r >= 3 * m) + 2 * (4 * gr >= 3 * m) + 4 * (4 * b >= 3 * m);
    }
}

// In a level with a reduced view (screenblocks < 10, see BLOCKS), only the
// view window is shown, stretched to COLSx(ROWS-1), above a status text line.
void I_FinishUpdate(void)
{
    int level = gamestate == GS_LEVEL && screenblocks < 10 && !automapactive;
    int x0 = level ? viewwindowx : 0, y0 = level ? viewwindowy : 0;
    int w = level ? scaledviewwidth : SCREENWIDTH, h = level ? viewheight : SCREENHEIGHT;
    int rows = level ? ROWS - 1 : ROWS;
    unsigned xs = (w << 16) / COLS, ys = (h << 16) / (2 * rows);
    char cur = 0;
    tx(0x1b); tx('['); tx('H');
    for (int r = 0; r < rows; r++) {
        const byte *a = I_VideoBuffer + (y0 + ((2 * r * ys + ys / 2) >> 16)) * SCREENWIDTH + x0;
        const byte *b = I_VideoBuffer + (y0 + (((2 * r + 1) * ys + ys / 2) >> 16)) * SCREENWIDTH + x0;
        for (unsigned c = 0, x = xs / 2; c < COLS; c++, x += xs) {
            byte pa = a[x >> 16], pb = b[x >> 16];
            char ch = ramp[(luma[pa] + luma[pb]) * 135 >> 10];    // 0..67
            char t = tint[luma[pa] >= luma[pb] ? pa : pb];    // the brighter pixel's hue
            if (COLOR && ch != ' ' && t != cur)                // colour only changes when it shows
                tx(0x1b), tx('['), tx('9'), tx(cur = t), tx('m');
            tx(ch);
        }
        if (r + 1 < rows) tx('\r'), tx('\n');
    }
    if (COLOR) tx(0x1b), tx('['), tx('0'), tx('m');
    if (level) {
        const player_t *p = &players[consoleplayer];
        ammotype_t am = weaponinfo[p->readyweapon].ammo;
        printf("\n HEALTH %3d%%   ARMOR %3d%%   AMMO %3d   WEAPON %d   KEYS %c%c%c          ",
               p->health, p->armorpoints, am == am_noammo ? 0 : p->ammo[am], p->readyweapon + 1,
               p->cards[it_bluecard] || p->cards[it_blueskull] ? 'B' : '-',
               p->cards[it_yellowcard] || p->cards[it_yellowskull] ? 'Y' : '-',
               p->cards[it_redcard] || p->cards[it_redskull] ? 'R' : '-');
    }
}

#endif

void DG_DrawFrame(void) {}
void DG_Init(void) {}
void DG_SetWindowTitle(const char *t) { (void)t; }

// ---- entry
void dg_Create(void);
void D_DoomMain(void);

int main(void)
{
    static char *argv[] = { "doom", "-iwad", "doom1.wad", DOOM_ARGS NULL };
    myargc = sizeof argv / sizeof *argv - 1;
    myargv = argv;
    screenblocks = BLOCKS;      // no config file: these stay
    detailLevel = LOWDETAIL;
    dg_Create();
    D_DoomMain();
    return 0;
}
