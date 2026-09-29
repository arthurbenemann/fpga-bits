// Fast FixedDiv, replacing m_fixed.c's (weakened in the Makefile). The
// overflow check below is unchanged from upstream: when it doesn't clamp,
// abs(a) < abs(b)<<14, so the true quotient magnitude stays under 2^30 and
// fits comfortably in 32 bits. That lets the division run as a specialized
// 48-bit-by-32-bit magnitude divide (32 bits of a, plus the 16 zero bits
// <<16 appends) instead of libgcc's generic 64/64 __divdi3 (~400
// instructions per call, hit from the renderer and physics every frame).
// Bit-exact against the original: see /tmp/rvtest/fixed_v2_test.c (35M+
// random pairs plus edge/boundary sweeps, 0 mismatches).
#include <stdlib.h>
#include <limits.h>

#include "doomtype.h"
#include "m_fixed.h"

// (a << 16) / d as unsigned magnitudes. Phase 1 divides a by d directly,
// shifting d up to align its top bit with a's (clz-based, so it costs one
// iteration per quotient bit instead of one per bit of a -- the difference
// matters because the hottest 32-bit divide elsewhere in the port,
// 0xffffffffu/scale, has a maximally-wide numerator, and libgcc's own
// __udivsi3 pays for that gap too via a slower doubling search). Phase 2
// continues the same restoring division for the 16 appended fraction bits.
static uint32_t udiv_a16(uint32_t a, uint32_t d)
{
    uint32_t q = 0, r;
    if (a >= d) {
        int shift = __builtin_clz(d) - __builtin_clz(a);
        uint32_t db = d << shift;
        for (int i = 0; i <= shift; i++) {
            q <<= 1;
            if (a >= db) { a -= db; q |= 1; }
            db >>= 1;
        }
        r = a;
    } else {
        r = a;
    }
    for (int i = 0; i < 16; i++) {
        r <<= 1;
        q <<= 1;
        if (r >= d) { r -= d; q |= 1; }
    }
    return q;
}

fixed_t FixedDiv(fixed_t a, fixed_t b)
{
    if ((abs(a) >> 14) >= abs(b))
        return (a ^ b) < 0 ? INT_MIN : INT_MAX;
    uint32_t q = udiv_a16((uint32_t)abs(a), (uint32_t)abs(b));
    return (a ^ b) < 0 ? -(fixed_t)q : (fixed_t)q;
}
