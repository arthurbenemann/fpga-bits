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
#include "v_video.h"
#include "w_file.h"
#include "z_zone.h"

#define IO(off) (*(volatile uint32_t *)(0x400000 + (off)))
#define UART_DAT 0x8
#define UART_CNTL 0x10
#define COUNTER 0x20
#define UART_RX 0x400
#define VIDEO 0x800     // W palette entry {index << 16 | 0xRGB}, R {front buf, frames[30:0]}
#define GAME 0x1000     // W {front_req, game_mode} (bits 1, 0): see video.v
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
// Double-buffered low-detail game view (video.v "game mode"): only makes
// sense filling the whole width at low detail, see r_draw_fast.c/I_FinishUpdate.
#define GAME_MODE (LOWDETAIL && BLOCKS == 10 && !TEXT)
#define GROWS 168       // packed view rows (SCREENHEIGHT - the status bar)

#if GAME_MODE
// gm_active: this frame's 3D view (r_draw_fast.c) and/or automap (AM_Drawer
// wrap below) draw into gm_back instead of the normal 320-wide screen, so
// the next frame's walls never overwrite this frame's still-shown sprites.
// Set once per frame in I_FinishUpdate.
int   gm_active;
byte *gm_back = FB;
static int gm_back_idx;     // buffer index (0/1) the next frame draws into
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
// The CPU clock is chosen by the bitstream (turbo or safe): read it from IO_CPUHZ.
static uint32_t ticks_ms;
#define TICKS_MS (ticks_ms ? ticks_ms : (ticks_ms = IO(0x10000) / 1000))
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

// ---- keys: a plain terminal sends only presses, so each key is released
// after HOLD_MS unless it repeats. WASD move, f fires, space uses, q/e strafe.
// load.py --keys instead sends real press/release events from evdev (press =
// code byte, release = 0xF0, code byte); the first 0xF0 seen switches to that
// exact mode for good, dropping the HOLD_MS timeout.
#define HOLD_MS 150
static uint32_t held[256];
static uint16_t evq[64];        // key, | 0x100 when pressed
static int ev_n, ev_i;
static int exact;               // load.py --keys protocol seen

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
        int c = rxq[rx_out++ % sizeof rxq];
        if (c == 0xf0) {
            exact = 1;
            while (rx_in == rx_out) rx_poll();     // the code byte follows right away
            int k = doomkey(rxq[rx_out++ % sizeof rxq]);
            if (held[k]) evq[ev_n++] = k;
            held[k] = 0;
            continue;
        }
        int k = doomkey(c);
        if (!held[k]) evq[ev_n++] = 0x100 | k;
        held[k] = exact ? 1 : now | 1;
    }
    if (!exact)
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

// ---- profiling: cycles spent in tics vs. rendering (bsp/planes/masked),
// via linker --wrap (Makefile's WRAP) so the upstream functions are
// unmodified. R_RenderPlayerView and its two split-out stages are each
// called at most once per frame, so the deltas don't nest.
static uint32_t prof_tic, prof_render, prof_planes, prof_masked, prof_tics;

extern void __real_TryRunTics(void);
void __wrap_TryRunTics(void)
{
    uint32_t t0 = IO(COUNTER);
    __real_TryRunTics();
    prof_tic += IO(COUNTER) - t0;
}

extern void __real_G_Ticker(void);
void __wrap_G_Ticker(void)
{
    prof_tics++;
    __real_G_Ticker();
}

#if GAME_MODE
// Menu over a level (see I_FinishUpdate): the view stays a still picture in the
// normal 320-wide layout and Doom's own overlays (HUD text, pause patch, menu)
// are composed onto a fresh copy of it in view_scratch, then copied over the
// screen at the end of the frame. Unchanged bytes are rewritten with identical
// values, so only what actually moved (skull, slider, text) changes on screen,
// and nothing ever ghosts, like Doom re-rendering the view under the menu.
static byte view_scratch[SCREENWIDTH * SCREENHEIGHT] __attribute__((aligned(4)));  // a normal-stride canvas
static byte menu_snap[SCREENWIDTH / 2 * GROWS] __attribute__((aligned(4)));        // the clean view under the menu, packed
static int  menu_snap_ok;   // menu_snap holds the current level's view
static int  compose;        // this frame's overlays are going to view_scratch
static int  in_alt_buffer;  // between V_UseBuffer/V_RestoreBuffer (the status
                            // bar's own off-screen face/number compositing)
extern void __real_V_UseBuffer(byte *buffer);

// packed (160 wide, 1 byte/pixel) <-> normal layout (320 wide, pixels doubled),
// the 168 view rows, 4 packed pixels / 8 normal ones at a time (word aligned).
#define PACKED_BYTES (SCREENWIDTH / 2 * GROWS)
static void expand_view(uint32_t *d, const uint32_t *s)
{
    for (int i = 0; i < PACKED_BYTES / 4; i++) {
        uint32_t w = *s++;
        *d++ = (w & 0xff) * 0x101 | (w & 0xff00) * 0x10100;
        *d++ = (w >> 16 & 0xff) * 0x101 | (w >> 24) * 0x1010000;
    }
}
static void pack_view(uint32_t *d, const uint32_t *s)
{
    for (int i = 0; i < PACKED_BYTES / 4; i++, s += 2)
        *d++ = (s[0] & 0xff) | (s[0] >> 16 & 0xff) << 8 | (s[1] & 0xff) << 16 | (s[1] >> 16 & 0xff) << 24;
}
#endif

extern void __real_R_RenderPlayerView(player_t *player);
void __wrap_R_RenderPlayerView(player_t *player)
{
#if GAME_MODE
    if (!gm_active && menuactive && !automapactive && gamestate == wipegamestate
        && screenblocks == 10 && detailLevel) {
        if (menu_snap_ok) {         // frozen view: don't render, compose the overlays
            expand_view((uint32_t *)view_scratch, (uint32_t *)menu_snap);
            memcpy(view_scratch + SCREENWIDTH * GROWS, FB + SCREENWIDTH * GROWS,
                   SCREENWIDTH * (SCREENHEIGHT - GROWS));        // status bar as drawn
            __real_V_UseBuffer(view_scratch);
            compose = 1;
            return;
        }
        __real_R_RenderPlayerView(player);  // no snapshot yet (menu opened during a wipe...)
        pack_view((uint32_t *)menu_snap, (uint32_t *)FB);
        menu_snap_ok = 1;
        return;
    }
#endif
    uint32_t t0 = IO(COUNTER);
    __real_R_RenderPlayerView(player);
    prof_render += IO(COUNTER) - t0;
}

extern void __real_R_DrawPlanes(void);
void __wrap_R_DrawPlanes(void)
{
    uint32_t t0 = IO(COUNTER);
    __real_R_DrawPlanes();
    prof_planes += IO(COUNTER) - t0;
}

extern void __real_R_DrawMasked(void);
void __wrap_R_DrawMasked(void)
{
    uint32_t t0 = IO(COUNTER);
    __real_R_DrawMasked();
    prof_masked += IO(COUNTER) - t0;
}

// ---- game mode overlays: am_map.c draws the automap via its own 'fb'
// pointer (not v_video.c), and both it and v_video.c's patch/block blitters
// (HUD messages, the "paused" patch, the automap's numbered marks, the wipe
// snapshot) normally write straight into the 320-wide screen -- which, in
// game mode, is gm_back's *packed* 160-wide memory misread at the wrong
// stride. Both are redirected here instead of touching am_map.c/v_video.c.
#if GAME_MODE

// am_map.c's AM_initVariables() does 'fb = I_VideoBuffer' once, when the map
// is (re)activated from AM_Responder (its caller, g_game.c, is a separate
// translation unit, so unlike AM_Start -- which AM_Responder calls locally
// and gcc inlines, leaving no call left for --wrap to catch -- this one is
// always a real call): swapping I_VideoBuffer just around it makes 'fb'
// point at our canvas for that whole automap session, without editing
// am_map.c. Harmless to bracket every event, not just the activating one.
extern bool __real_AM_Responder(event_t *ev);
bool __wrap_AM_Responder(event_t *ev)
{
    byte *save = I_VideoBuffer;
    I_VideoBuffer = view_scratch;
    bool ret = __real_AM_Responder(ev);
    I_VideoBuffer = save;
    return ret;
}

// Folds the map (half the horizontal resolution, like the Low detail
// drawers) into gm_back after each frame, so it's double-buffered too.
// The marks feature (numbered player markers) draws via V_DrawPatch straight
// into the real screen though (see below), and this full-view fold papers
// over it again right after -- marks don't show in game mode; a minor, rare
// cosmetic loss, not worth plumbing further.
extern void __real_AM_Drawer(void);
void __wrap_AM_Drawer(void)
{
    __real_AM_Drawer();
    if (gm_active)
        for (int y = 0; y < GROWS; y++)
            for (int xp = 0; xp < 160; xp++)
                gm_back[y * 160 + xp] = view_scratch[y * SCREENWIDTH + xp * 2];
}

extern void __real_V_UseBuffer(byte *buffer);
void __wrap_V_UseBuffer(byte *buffer) { in_alt_buffer = 1; __real_V_UseBuffer(buffer); }

extern void __real_V_RestoreBuffer(void);
void __wrap_V_RestoreBuffer(void)
{
    in_alt_buffer = 0;
    __real_V_RestoreBuffer();
    if (compose) __real_V_UseBuffer(view_scratch);
}

// Copies between gm_back (packed, 160 wide) and a normal-stride rectangle of
// view_scratch, sampling/duplicating every other column -- the same 1:2
// mapping the Low detail drawers use -- so upstream's normal-stride blitters
// can run unmodified against a faithful copy of the current view, then fold
// back at half width.
static void gview_expand(int x0, int y0, int w, int h)
{
    for (int y = y0; y < y0 + h; y++)
        for (int x = x0; x < x0 + w; x++)
            view_scratch[y * SCREENWIDTH + x] = gm_back[y * 160 + (x >> 1)];
}
static void gview_fold(int x0, int y0, int w, int h)
{
    for (int y = y0; y < y0 + h; y++)
        for (int xp = x0 >> 1; xp <= (x0 + w - 1) >> 1; xp++)
            gm_back[y * 160 + xp] = view_scratch[y * SCREENWIDTH + xp * 2];
}

typedef void (*patchfn_t)(int, int, patch_t *);
static void packed_patch(int x, int y, patch_t *patch, patchfn_t real)
{
    int ex = x - patch->leftoffset, ey = y - patch->topoffset;
    int w = patch->width, h = patch->height;
    if (!gm_active || in_alt_buffer || ex < 0 || ey < 0 || ey + h > GROWS) {
        real(x, y, patch);      // status bar backing buffer, or outside the view: untouched
        return;
    }
    gview_expand(ex, ey, w, h);
    __real_V_UseBuffer(view_scratch);
    real(x, y, patch);
    __real_V_RestoreBuffer();
    gview_fold(ex, ey, w, h);
}

extern void __real_V_DrawPatch(int x, int y, patch_t *patch);
void __wrap_V_DrawPatch(int x, int y, patch_t *patch) { packed_patch(x, y, patch, __real_V_DrawPatch); }

extern void __real_V_DrawPatchDirect(int x, int y, patch_t *patch);
void __wrap_V_DrawPatchDirect(int x, int y, patch_t *patch) { packed_patch(x, y, patch, __real_V_DrawPatchDirect); }

extern void __real_V_DrawBlock(int x, int y, int width, int height, byte *src);
void __wrap_V_DrawBlock(int x, int y, int width, int height, byte *src)
{
    if (!gm_active || in_alt_buffer || x < 0 || y < 0 || y + height > GROWS) {
        __real_V_DrawBlock(x, y, width, height, src);
        return;
    }
    gview_expand(x, y, width, height);
    __real_V_UseBuffer(view_scratch);
    __real_V_DrawBlock(x, y, width, height, src);
    __real_V_RestoreBuffer();
    gview_fold(x, y, width, height);
}
#else
extern bool __real_AM_Responder(event_t *ev);
bool __wrap_AM_Responder(event_t *ev) { return __real_AM_Responder(ev); }
extern void __real_AM_Drawer(void);
void __wrap_AM_Drawer(void) { __real_AM_Drawer(); }
extern void __real_V_UseBuffer(byte *buffer);
void __wrap_V_UseBuffer(byte *buffer) { __real_V_UseBuffer(buffer); }
extern void __real_V_RestoreBuffer(void);
void __wrap_V_RestoreBuffer(void) { __real_V_RestoreBuffer(); }
extern void __real_V_DrawPatch(int x, int y, patch_t *patch);
void __wrap_V_DrawPatch(int x, int y, patch_t *patch) { __real_V_DrawPatch(x, y, patch); }
extern void __real_V_DrawPatchDirect(int x, int y, patch_t *patch);
void __wrap_V_DrawPatchDirect(int x, int y, patch_t *patch) { __real_V_DrawPatchDirect(x, y, patch); }
extern void __real_V_DrawBlock(int x, int y, int width, int height, byte *src);
void __wrap_V_DrawBlock(int x, int y, int width, int height, byte *src) { __real_V_DrawBlock(x, y, width, height, src); }
#endif

// The status bar is not double-buffered by the hardware: it always scans the
// one copy at FB+53760, in the last third of the frame's active time. Its
// numbers are erased then redrawn (ST_Drawer), so drawing them at a random
// time (right after a long tic, say) lets the scan catch the erased state: the
// ammo/health flicker. In a double-buffered frame the draw is therefore held
// back until I_FinishUpdate has flipped the view, which lands at the top of
// the frame, ~10 ms before the scan reaches the status bar.
extern void __real_ST_Drawer(bool fullscreen, bool refresh);
#if GAME_MODE
static int  st_pending, st_fs, st_refresh;
static void st_run(void)
{
    if (!st_pending) return;
    st_pending = 0;
    __real_ST_Drawer(st_fs, st_refresh);
    st_fs = st_refresh = 0;
}
void __wrap_ST_Drawer(bool fullscreen, bool refresh)
{
    if (gm_active) {
        st_pending = 1;
        st_fs |= fullscreen;
        st_refresh |= refresh;
        return;
    }
    __real_ST_Drawer(fullscreen, refresh);
}

// Level <-> other screens (and the melt itself) are drawn in the normal
// layout: from the wipe's start screen until its last frame (in_wipe,
// wipe_done) I_FinishUpdate stays out of game mode. The start screen is what
// is on display now -- in game mode the packed front buffer, which
// leave_game_mode() turns back into a normal picture first (otherwise the
// melt would start from the packed bytes misread at 320 wide).
static int in_wipe, wipe_done;
static void leave_game_mode(void);
extern int __real_wipe_StartScreen(int x, int y, int width, int height);
int __wrap_wipe_StartScreen(int x, int y, int width, int height)
{
    in_wipe = 1;
    wipe_done = 0;
    if (gm_active) {
        st_run();
        leave_game_mode();
        gm_active = 0;
    }
    menu_snap_ok = 0;
    return __real_wipe_StartScreen(x, y, width, height);
}

extern int __real_wipe_ScreenWipe(int wipeno, int x, int y, int width, int height, int ticks);
int __wrap_wipe_ScreenWipe(int wipeno, int x, int y, int width, int height, int ticks)
{
    int done = __real_wipe_ScreenWipe(wipeno, x, y, width, height, ticks);
    if (done) wipe_done = 1;
    return done;
}
#else
void __wrap_ST_Drawer(bool fullscreen, bool refresh) { __real_ST_Drawer(fullscreen, refresh); }
extern int __real_wipe_StartScreen(int x, int y, int width, int height);
int __wrap_wipe_StartScreen(int x, int y, int width, int height) { return __real_wipe_StartScreen(x, y, width, height); }
extern int __real_wipe_ScreenWipe(int wipeno, int x, int y, int width, int height, int ticks);
int __wrap_wipe_ScreenWipe(int wipeno, int x, int y, int width, int height, int ticks) { return __real_wipe_ScreenWipe(wipeno, x, y, width, height, ticks); }
#endif

static uint32_t pct(uint32_t x, uint32_t d) { return (uint64_t)x * 100 / d; }

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

#if GAME_MODE
static void wait_frame_end(void)    // the fetcher has read the last line: vertical blanking
{
    uint32_t f = IO(VIDEO) & 0x7fffffff;
    while ((IO(VIDEO) & 0x7fffffff) == f) rx_poll();
}

// Game mode -> normal layout, without showing garbage: the picture on screen
// (the front buffer, packed) is kept in menu_snap; GAME=0 takes effect at the
// next frame's start, and expanding it into the normal-layout screen starts in
// the blanking before that (4 ms head start on the scan, which then trails the
// copy).
static void leave_game_mode(void)
{
    memcpy(menu_snap, FB + (gm_back_idx ^ 1) * PACKED_BYTES, PACKED_BYTES);
    IO(GAME) = 0;
    wait_frame_end();
    expand_view((uint32_t *)FB, (uint32_t *)menu_snap);
    gm_back = FB;
}

// Normal layout -> game mode: the finished picture in FB is packed into
// view_scratch, GAME=1 (front buffer 0) lands at the next frame's start, and
// it is copied into buffer 0 in the blanking before that.
static void enter_game_mode(void)
{
    pack_view((uint32_t *)view_scratch, (uint32_t *)FB);
    IO(GAME) = 1;
    wait_frame_end();
    memcpy(FB, view_scratch, PACKED_BYTES);
    gm_back_idx = 1;
}
#endif

// Frames per second and a profile breakdown on the UART, every 64 frames.
void I_FinishUpdate(void)
{
    static uint32_t n, t0, c0;
#if GAME_MODE
    if (compose) {          // menu frame (R_RenderPlayerView wrap): overlays onto the screen at once
        compose = 0;
        __real_V_RestoreBuffer();
        memcpy(FB, view_scratch, SCREENWIDTH * SCREENHEIGHT);
    }
    // Modes, decided once per frame for the *next* one (this frame is already
    // drawn and about to be flipped to front):
    //  - level view / automap (AM_Drawer wrap above fills gm_back instead of
    //    R_RenderPlayerView): packed double buffer, flipped here.
    //  - menu over a level: back to the normal layout, view frozen as a still
    //    picture (menu_snap) with the overlays composed onto it each frame
    //    (R_RenderPlayerView wrap above), so nothing ghosts.
    //  - everything else (title, intermission, wipes, other view sizes): the
    //    normal single-buffered layout; Doom redraws those full frames itself.
    int fullview  = screenblocks == 10 && detailLevel;
    int want_view = gamestate == GS_LEVEL && fullview && !automapactive && !menuactive;
    int want_map  = gamestate == GS_LEVEL && fullview && automapactive;
    int want_menu = gamestate == GS_LEVEL && fullview && menuactive && !automapactive;

    if (in_wipe && wipe_done) in_wipe = 0;      // the last frame: the picture is complete
    if (in_wipe) {
        // melting in the normal layout (gm_active is off since the start screen)
    } else if (want_view || want_map) {
        if (gm_active) {                                     // back buffer just drawn: show it
            IO(GAME) = 1 | gm_back_idx << 1;
            while ((IO(VIDEO) >> 31) != (uint32_t)gm_back_idx) rx_poll();
            gm_back_idx ^= 1;
            st_run();                                        // status bar: see __wrap_ST_Drawer
        } else {
            enter_game_mode();
            gm_active = 1;
        }
        menu_snap_ok = 0;
    } else {
        st_run();
        if (gm_active) {
            leave_game_mode();
            gm_active = 0;
            menu_snap_ok = want_menu;
        } else if (!want_menu) {
            menu_snap_ok = 0;
        }
        IO(GAME) = 0;
    }
    gm_back = FB + gm_back_idx * 26880;
#endif
    if (++n % 64) return;
    uint32_t t = DG_GetTicksMs(), c = IO(COUNTER), d = c - c0;
    uint32_t bsp = prof_render - prof_planes - prof_masked, other = d - prof_tic - prof_render;
    printf("\r%d.%d fps  tics %d/frame  tic %d%% bsp %d%% planes %d%% masked %d%% other %d%%   ",
           640000 / (t - t0) / 10, 640000 / (t - t0) % 10, prof_tics / 64,
           pct(prof_tic, d), pct(bsp, d), pct(prof_planes, d), pct(prof_masked, d), pct(other, d));
    t0 = t; c0 = c;
    prof_tic = prof_render = prof_planes = prof_masked = prof_tics = 0;
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
