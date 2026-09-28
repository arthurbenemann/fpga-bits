// getkey.c -- UART-based replacement for the PS/2 keyboard (PS2IC.c).
// Non-blocking, like the original: returns 0 when no key is ready.
//
// The old GUI's cursor mode moves with PS/2 numpad keys (KP8/KP2/KP4/KP6,
// keymap.h). A terminal sends arrow keys as the escape sequence
// ESC '[' 'A'/'B'/'C'/'D' (up/down/right/left), so that's decoded here into
// the same KP8/KP2/KP6/KP4 codes -- one byte at a time, since the UART
// gives us bytes one at a time and getKey() must not block. A lone Esc
// (nothing follows within the state machine) still comes through as ESC,
// same as the original's "cancel" key. Everything else -- typed algebraic
// moves, backspace, Enter -- passes through unchanged.
#include <stdint.h>
#include "keymap.h"

#ifdef HOST
#include <stdio.h>
#include <stdlib.h>
static int uart_poll(int *out)
{
    static int eofs;
    int c = getchar();
    if (c == EOF) {
        // Real hardware would just keep polling forever; for a host test
        // run off a fixed script of keys we want it to exit cleanly once
        // input is exhausted, instead of idle-spinning (and racing a
        // `timeout` kill against the last frame write) forever.
        if (++eofs > 1000) exit(0);
        return 0;
    }
    eofs = 0;
    *out = c;
    return 1;
}
#endif

void initKBD(void) { }

#ifdef HOST
unsigned char getKey(void)
{
    static int esc_state;   // 0 idle, 1 saw ESC, 2 saw ESC [
    static int pending = -1;

    for (;;) {
        int c;
        if (pending >= 0) { c = pending; pending = -1; }
        else if (!uart_poll(&c)) return 0;

        switch (esc_state) {
        case 0:
            if (c == ESC) { esc_state = 1; continue; }
            return (unsigned char)c;
        case 1:
            if (c == '[') { esc_state = 2; continue; }
            esc_state = 0;
            pending = c;        // reprocess this byte as a fresh key next time
            return ESC;
        default:                // 2: ESC [ <c>
            esc_state = 0;
            switch (c) {
            case 'A': return KP8;   // up
            case 'B': return KP2;   // down
            case 'C': return KP6;   // right
            case 'D': return KP4;   // left
            default:  return (unsigned char)c;
            }
        }
    }
}
#else
#include "../../fbcon.h"
// fbcon.c's con_key() already turns --keys press/release events and ESC [ A..D into
// K_* codes and Ctrl+C into 3.
unsigned char getKey(void)
{
    int k = con_key();
    switch (k) {
    case -1:      return 0;
    case K_UP:    return KP8;
    case K_DOWN:  return KP2;
    case K_RIGHT: return KP6;
    case K_LEFT:  return KP4;
    case 0x7f:    return BKSP;
    default:      return k;
    }
}
#endif
