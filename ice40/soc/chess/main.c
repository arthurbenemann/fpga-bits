// picChess menu program -- the ORIGINAL GUI (chess/gui/: chessVideo.c,
// chessInterface.c/h, chessSet.h, and chessGame.c's state machine, all from
// before the project's 2014 refactor into an xboard engine) driving the
// current engine (chess/chessEngine.c and friends, from the "orderedMoveGen"
// branch). Only the hardware layer changed -- see chess/vga/: VGA.h/VGA.c
// now draw the old GUI's monochrome 200x150 bitmap onto this SoC's 320x200
// HDMI framebuffer instead of dsPIC SPI/DMA hardware; text.c/graphics.c/
// font.h are the unmodified dsPIC library, since they only ever touched
// VH/VA through VGA.h's constants; getkey.c replaces the PS/2 keyboard with
// UART bytes (typed algebraic moves, or arrow keys as the ESC '[' A/B/C/D
// sequence a terminal sends, for the old GUI's cursor-based move entry);
// uart2.c/clock.c/audio.h are thin/no-op stubs for the serial move echo,
// the (nonexistent) RTC, and dropped Audio.
//
// Splash screen -> pick game type (PvP/PvC/CvP/CvC) -> pick search depth
// (Easy/Medium/Hard/Suicide, i.e. depth 3/4/5/6) -> play. Ctrl+C (0x03)
// always returns to the menu; the old GUI itself has no such concept (it
// expected a power cycle), so this one byte is intercepted here rather
// than touching chess/gui/.
#include "VGA.h"
#include "getkey.h"
#include "UART2.h"

int chessGame(unsigned char key);
void chessInit(void);

int main(void)
{
    initVGA();
    initKBD();
    initU2();
    chessInit();

    for (;;) {
        unsigned char key = getKey();
        if (key == 0x03) return 0;       // Ctrl+C: back to the menu
        if (chessGame(key)) break;       // checkmate/stalemate; final screen is already up
    }

    while (!getKey());                   // any key to leave the announcement
    return 0;
}
