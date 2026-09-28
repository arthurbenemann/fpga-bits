// Text console on the 320x200 8bpp HDMI framebuffer (see video.v, soc.v):
// 40x25 characters, 8x8 font (ASCII 32..126). Claims palette entries 0
// (background, black) and 15 (foreground, white) -- graphics programs that
// also use the console should leave those two indices alone.
//
//   con_init()           clears the screen, sets palette 0=black/15=white,
//                         turns game mode off (IO_GAME <- 0), homes the
//                         cursor and resets colours to white-on-black. Call
//                         once before any other con_ function.
//   con_clear()           clears the screen and homes the cursor (keeps colours)
//   con_setcolor(fg, bg)  palette index (0..255) used by characters drawn after
//   con_putc(c)           draws one character; handles \n \r \b, and scrolls
//                         (memmove of the framebuffer) when the last line fills
//   con_attach()          makes putchar()/printf() write to both the console
//                         and the UART (default: UART only, so programs that
//                         don't call this are unaffected)
#ifndef FBCON_H
#define FBCON_H

void con_init(void);
void con_clear(void);
void con_setcolor(unsigned fg, unsigned bg);
void con_putc(int c);
void con_attach(void);
void con_at(unsigned col, unsigned row);   // cursor to column 0..39, row 0..24

// Key presses from the host (see load.py): a byte, or K_*; -1 if none pending.
enum { K_UP = 0x100, K_DOWN, K_LEFT, K_RIGHT };
int con_key(void);
int con_waitkey(void);

#endif
