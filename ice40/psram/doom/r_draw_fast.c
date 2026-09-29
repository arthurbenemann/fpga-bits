// Fast column/span drawers, replacing r_draw.c's (weakened in the
// Makefile). Bit-exact with upstream: same expressions, same evaluation
// order, same RANGECHECK guards (defined via doomdef.h for this build) --
// only the loop is restructured, unrolled by 4 with a scalar remainder, to
// cut per-pixel loop-control overhead (decrement/compare/branch). dc_x/
// dc_yl/dc_yh/dc_source/dc_colormap etc. are the upstream globals (r_draw.h);
// ylookup/columnofs/fuzzoffset/fuzzpos have no header, so they're declared
// here as in r_draw.c. The framebuffer (ylookup targets) is SPRAM, so
// stores are cheap; dc_source/dc_colormap/ds_source/ds_colormap reads go
// through the PSRAM cache.
//
// GAME_MODE (dg_uart.c, BLOCKS=10 && LOWDETAIL=1 && !TEXT): the *Low
// variants below are the only drawers used for the 3D view then (walls,
// floors and, via R_DrawMaskedColumn, sprites -- everything detailshift
// touches), so gm_active picked once per column/span (not per pixel) is
// enough to redirect the whole view into gm_back, the current back buffer
// of video.v's double-buffered game mode, packed 1 byte/pixel with a
// 160-wide stride instead of the normal 320-wide screen. dc_x/ds_x1/x2 are
// already in viewwidth (0..159) space -- the upstream Low code below only
// widens into screen space (<<1, two writes) for the normal path.
#include "r_local.h"
#include "r_state.h"
#include "i_video.h"
#include "i_system.h"

extern byte *ylookup[];
extern int columnofs[];
extern int fuzzoffset[];
extern int fuzzpos;

#define FUZZTABLE 50

// Same condition as dg_uart.c's (LOWDETAIL/BLOCKS/TEXT come from the Makefile
// -D's, added alongside r_draw_fast.o's own -O3 there).
#define GAME_MODE (LOWDETAIL && BLOCKS == 10 && !TEXT)

#if GAME_MODE
#define GSTRIDE 160
extern int   gm_active;    // dg_uart.c: this frame's view goes to gm_back
extern byte *gm_back;
// fuzzoffset[] is +-SCREENWIDTH (a row, for the normal 320-wide screen);
// same signs, scaled to the packed buffer's 160-wide stride.
static const int game_fuzzoffset[FUZZTABLE] = {
    GSTRIDE,-GSTRIDE,GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,
    GSTRIDE,GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,
    GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,-GSTRIDE,-GSTRIDE,-GSTRIDE,
    GSTRIDE,-GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,
    GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,-GSTRIDE,GSTRIDE,
    GSTRIDE,-GSTRIDE,-GSTRIDE,-GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,
    GSTRIDE,GSTRIDE,-GSTRIDE,GSTRIDE,GSTRIDE,-GSTRIDE,GSTRIDE
};
#endif

// ---- R_DrawColumn ----------------------------------------------------
void R_DrawColumn(void)
{
    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[dc_x];
    const byte *source = dc_source;
    const byte *colormap = dc_colormap;
    fixed_t fracstep = dc_iscale;
    fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
    count++;

    while (count >= 4) {
        dest[0]           = colormap[source[(frac             >> FRACBITS) & 127]];
        dest[SCREENWIDTH]   = colormap[source[((frac+fracstep)  >> FRACBITS) & 127]];
        dest[SCREENWIDTH*2] = colormap[source[((frac+2*fracstep)>> FRACBITS) & 127]];
        dest[SCREENWIDTH*3] = colormap[source[((frac+3*fracstep)>> FRACBITS) & 127]];
        frac += fracstep * 4;
        dest += SCREENWIDTH * 4;
        count -= 4;
    }
    while (count-- > 0) {
        *dest = colormap[source[(frac >> FRACBITS) & 127]];
        dest += SCREENWIDTH;
        frac += fracstep;
    }
}

void R_DrawColumnLow(void)
{
    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#if GAME_MODE
    if (gm_active) {
#ifdef RANGECHECK
        if ((unsigned)dc_x >= GSTRIDE || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
            I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif
        byte *dest = gm_back + dc_yl * GSTRIDE + dc_x;
        const byte *source = dc_source;
        const byte *colormap = dc_colormap;
        fixed_t fracstep = dc_iscale;
        fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
        count++;

        while (count >= 4) {
            dest[0]          = colormap[source[(frac             >> FRACBITS) & 127]];
            dest[GSTRIDE]    = colormap[source[((frac+fracstep)  >> FRACBITS) & 127]];
            dest[GSTRIDE*2]  = colormap[source[((frac+2*fracstep)>> FRACBITS) & 127]];
            dest[GSTRIDE*3]  = colormap[source[((frac+3*fracstep)>> FRACBITS) & 127]];
            frac += fracstep * 4;
            dest += GSTRIDE * 4;
            count -= 4;
        }
        while (count-- > 0) {
            *dest = colormap[source[(frac >> FRACBITS) & 127]];
            dest += GSTRIDE;
            frac += fracstep;
        }
        return;
    }
#endif

    int x = dc_x << 1;
#ifdef RANGECHECK
    if ((unsigned)x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[x];
    byte *dest2 = ylookup[dc_yl] + columnofs[x + 1];
    const byte *source = dc_source;
    const byte *colormap = dc_colormap;
    fixed_t fracstep = dc_iscale;
    fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
    count++;

    while (count >= 4) {
        byte c0 = colormap[source[(frac             >> FRACBITS) & 127]];
        byte c1 = colormap[source[((frac+fracstep)  >> FRACBITS) & 127]];
        byte c2 = colormap[source[((frac+2*fracstep)>> FRACBITS) & 127]];
        byte c3 = colormap[source[((frac+3*fracstep)>> FRACBITS) & 127]];
        dest[0] = dest2[0] = c0;
        dest[SCREENWIDTH] = dest2[SCREENWIDTH] = c1;
        dest[SCREENWIDTH*2] = dest2[SCREENWIDTH*2] = c2;
        dest[SCREENWIDTH*3] = dest2[SCREENWIDTH*3] = c3;
        frac += fracstep * 4;
        dest += SCREENWIDTH * 4;
        dest2 += SCREENWIDTH * 4;
        count -= 4;
    }
    while (count-- > 0) {
        *dest2 = *dest = colormap[source[(frac >> FRACBITS) & 127]];
        dest += SCREENWIDTH;
        dest2 += SCREENWIDTH;
        frac += fracstep;
    }
}

// ---- R_DrawFuzzColumn --------------------------------------------------
void R_DrawFuzzColumn(void)
{
    if (!dc_yl)
        dc_yl = 1;
    if (dc_yh == viewheight - 1)
        dc_yh = viewheight - 2;

    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawFuzzColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[dc_x];
    count++;

    // fuzzpos wraps every FUZZTABLE (50) steps, not a power of 2, so it
    // isn't cheap to batch -- unrolling still removes the frac/fracstep
    // bookkeeping the original carried but never used.
    while (count-- > 0) {
        *dest = colormaps[6*256 + dest[fuzzoffset[fuzzpos]]];
        if (++fuzzpos == FUZZTABLE)
            fuzzpos = 0;
        dest += SCREENWIDTH;
    }
}

void R_DrawFuzzColumnLow(void)
{
    if (!dc_yl)
        dc_yl = 1;
    if (dc_yh == viewheight - 1)
        dc_yh = viewheight - 2;

    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#if GAME_MODE
    if (gm_active) {
#ifdef RANGECHECK
        if ((unsigned)dc_x >= GSTRIDE || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
            I_Error("R_DrawFuzzColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif
        byte *dest = gm_back + dc_yl * GSTRIDE + dc_x;
        count++;
        while (count-- > 0) {
            *dest = colormaps[6*256 + dest[game_fuzzoffset[fuzzpos]]];
            if (++fuzzpos == FUZZTABLE)
                fuzzpos = 0;
            dest += GSTRIDE;
        }
        return;
    }
#endif

    int x = dc_x << 1;
#ifdef RANGECHECK
    if ((unsigned)x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawFuzzColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[x];
    byte *dest2 = ylookup[dc_yl] + columnofs[x + 1];
    count++;

    while (count-- > 0) {
        *dest = colormaps[6*256 + dest[fuzzoffset[fuzzpos]]];
        *dest2 = colormaps[6*256 + dest2[fuzzoffset[fuzzpos]]];
        if (++fuzzpos == FUZZTABLE)
            fuzzpos = 0;
        dest += SCREENWIDTH;
        dest2 += SCREENWIDTH;
    }
}

// ---- R_DrawTranslatedColumn (no &127 mask, matches upstream) -------------
void R_DrawTranslatedColumn(void)
{
    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#ifdef RANGECHECK
    if ((unsigned)dc_x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[dc_x];
    const byte *source = dc_source;
    const byte *colormap = dc_colormap;
    const byte *translation = dc_translation;
    fixed_t fracstep = dc_iscale;
    fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
    count++;

    while (count >= 4) {
        dest[0]             = colormap[translation[source[(frac             >> FRACBITS)]]];
        dest[SCREENWIDTH]   = colormap[translation[source[((frac+fracstep)  >> FRACBITS)]]];
        dest[SCREENWIDTH*2] = colormap[translation[source[((frac+2*fracstep)>> FRACBITS)]]];
        dest[SCREENWIDTH*3] = colormap[translation[source[((frac+3*fracstep)>> FRACBITS)]]];
        frac += fracstep * 4;
        dest += SCREENWIDTH * 4;
        count -= 4;
    }
    while (count-- > 0) {
        *dest = colormap[translation[source[frac >> FRACBITS]]];
        dest += SCREENWIDTH;
        frac += fracstep;
    }
}

void R_DrawTranslatedColumnLow(void)
{
    int count = dc_yh - dc_yl;
    if (count < 0)
        return;

#if GAME_MODE
    if (gm_active) {
#ifdef RANGECHECK
        if ((unsigned)dc_x >= GSTRIDE || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
            I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, dc_x);
#endif
        byte *dest = gm_back + dc_yl * GSTRIDE + dc_x;
        const byte *source = dc_source;
        const byte *colormap = dc_colormap;
        const byte *translation = dc_translation;
        fixed_t fracstep = dc_iscale;
        fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
        count++;

        while (count-- > 0) {
            *dest = colormap[translation[source[frac >> FRACBITS]]];
            dest += GSTRIDE;
            frac += fracstep;
        }
        return;
    }
#endif

    int x = dc_x << 1;
#ifdef RANGECHECK
    if ((unsigned)x >= SCREENWIDTH || dc_yl < 0 || dc_yh >= SCREENHEIGHT)
        I_Error("R_DrawColumn: %i to %i at %i", dc_yl, dc_yh, x);
#endif

    byte *dest = ylookup[dc_yl] + columnofs[x];
    byte *dest2 = ylookup[dc_yl] + columnofs[x + 1];
    const byte *source = dc_source;
    const byte *colormap = dc_colormap;
    const byte *translation = dc_translation;
    fixed_t fracstep = dc_iscale;
    fixed_t frac = dc_texturemid + (dc_yl - centery) * fracstep;
    count++;

    while (count-- > 0) {
        byte c = colormap[translation[source[frac >> FRACBITS]]];
        *dest = c;
        *dest2 = c;
        dest += SCREENWIDTH;
        dest2 += SCREENWIDTH;
        frac += fracstep;
    }
}

// ---- R_DrawSpan --------------------------------------------------------
void R_DrawSpan(void)
{
#ifdef RANGECHECK
    if (ds_x2 < ds_x1 || ds_x1 < 0 || ds_x2 >= SCREENWIDTH || (unsigned)ds_y > SCREENHEIGHT)
        I_Error("R_DrawSpan: %i to %i at %i", ds_x1, ds_x2, ds_y);
#endif

    unsigned int position = ((ds_xfrac << 10) & 0xffff0000) | ((ds_yfrac >> 6) & 0x0000ffff);
    unsigned int step     = ((ds_xstep << 10) & 0xffff0000) | ((ds_ystep >> 6) & 0x0000ffff);

    byte *dest = ylookup[ds_y] + columnofs[ds_x1];
    const byte *source = ds_source;
    const byte *colormap = ds_colormap;
    int count = ds_x2 - ds_x1 + 1;

    while (count >= 4) {
        unsigned p0 = position, p1 = position + step, p2 = p1 + step, p3 = p2 + step;
        dest[0] = colormap[source[((p0 >> 26)) | ((p0 >> 4) & 0x0fc0)]];
        dest[1] = colormap[source[((p1 >> 26)) | ((p1 >> 4) & 0x0fc0)]];
        dest[2] = colormap[source[((p2 >> 26)) | ((p2 >> 4) & 0x0fc0)]];
        dest[3] = colormap[source[((p3 >> 26)) | ((p3 >> 4) & 0x0fc0)]];
        position = p3 + step;
        dest += 4;
        count -= 4;
    }
    while (count-- > 0) {
        int spot = (position >> 26) | ((position >> 4) & 0x0fc0);
        *dest++ = colormap[source[spot]];
        position += step;
    }
}

void R_DrawSpanLow(void)
{
#ifdef RANGECHECK
    if (ds_x2 < ds_x1 || ds_x1 < 0 || ds_x2 >= SCREENWIDTH || (unsigned)ds_y > SCREENHEIGHT)
        I_Error("R_DrawSpan: %i to %i at %i", ds_x1, ds_x2, ds_y);
#endif

    unsigned int position = ((ds_xfrac << 10) & 0xffff0000) | ((ds_yfrac >> 6) & 0x0000ffff);
    unsigned int step     = ((ds_xstep << 10) & 0xffff0000) | ((ds_ystep >> 6) & 0x0000ffff);

#if GAME_MODE
    if (gm_active) {
        byte *dest = gm_back + ds_y * GSTRIDE + ds_x1;
        const byte *source = ds_source;
        const byte *colormap = ds_colormap;
        int count = ds_x2 - ds_x1 + 1;

        while (count-- > 0) {
            int spot = (position >> 26) | ((position >> 4) & 0x0fc0);
            *dest++ = colormap[source[spot]];
            position += step;
        }
        return;
    }
#endif

    int count = ds_x2 - ds_x1;
    int x1 = ds_x1 << 1;
    byte *dest = ylookup[ds_y] + columnofs[x1];
    const byte *source = ds_source;
    const byte *colormap = ds_colormap;
    count++;

    while (count-- > 0) {
        int spot = (position >> 26) | ((position >> 4) & 0x0fc0);
        byte c = colormap[source[spot]];
        dest[0] = c;
        dest[1] = c;
        dest += 2;
        position += step;
    }
}
