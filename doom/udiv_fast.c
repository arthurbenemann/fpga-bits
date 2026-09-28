// Fast 32-bit unsigned divide/modulo, replacing libgcc's __udivsi3 and
// __umodsi3 (rv32i_zmmul has no hardware divide) via linker --wrap
// (Makefile's WRAP) -- libgcc's div.o also defines __udivdi3/__divsf3/etc.
// that are still needed, so a same-named strong symbol would collide
// ("multiple definition") once that object is pulled in; --wrap only
// redirects the call sites, leaving the archive member alone. This speeds
// up SlopeDiv (tables.c, called from R_PointToAngle on every BSP split)
// and, bigger, the per-column dc_iscale = 0xffffffffu / scale in
// r_segs.c's R_RenderSegLoop/R_RenderMaskedSegRange, run once per screen
// column of every textured wall.
//
// The divisor is shifted up (clz-based) to align its top bit with the
// numerator's before the restoring-division loop, so the iteration count
// is the quotient's bit width, not the numerator's -- important here since
// 0xffffffffu/scale always has a maximally-wide (32-bit) numerator, a case
// a naive "skip the numerator's leading zeros" loop can't shorten at all.
//
// Correctness: unsigned division has one right answer, so there's no
// edge-case ambiguity (unlike FixedDiv's clamp); see
// /tmp/rvtest/udiv_v2_test.c (35M+ random pairs plus edge sweeps against
// a0/b0 and a0%b0, 0 mismatches, including the 0xffffffffu/scale pattern).
#include <stdint.h>

static unsigned int udiv_fast(unsigned int n, unsigned int d)
{
    if (!d) return 0xffffffffu;
    if (n < d) return 0;
    int shift = __builtin_clz(d) - __builtin_clz(n);
    unsigned int db = d << shift;
    unsigned int q = 0;
    for (int i = 0; i <= shift; i++) {
        q <<= 1;
        if (n >= db) { n -= db; q |= 1; }
        db >>= 1;
    }
    return q;
}

unsigned int __wrap___udivsi3(unsigned int n, unsigned int d)
{
    return udiv_fast(n, d);
}

unsigned int __wrap___umodsi3(unsigned int n, unsigned int d)
{
    return n - udiv_fast(n, d) * d;
}
