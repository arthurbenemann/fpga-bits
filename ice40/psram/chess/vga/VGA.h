// VGA.h -- public API kept from the original dsPIC VGA library (see the old
// picChess history: Firmware/VGA/VGA.h) so chessVideo.c/chessInterface.c/
// text.c/graphics.c compile completely unchanged. VGA.c below reimplements
// the body on top of this SoC's 320x200 8bpp HDMI framebuffer instead of a
// dsPIC SPI/DMA VGA signal generator; the resolution, VH/VA monochrome
// bitmap layout (1 bit/pixel, 16px/word, lineSize words per line) and every
// plotXxx()/putXxx() call site are unchanged, so chessVideo.c's direct
// pointer math into VH (posToVideoPtr, plotPiece, plotCursor) still lines
// up exactly.
//
//	Resolution kept at 200x150 (matches the original 8x8-cell, 16px-square
//	board layout in chessInterface.h's BOARD_SIZE=128). Our framebuffer is
//	320x200, so this is centred at 1x scale (2x would be 400x300 -- too
//	big to fit).
#ifndef VGA_H
#define VGA_H

//--------------- Constants ---------------------
#define	VRES	150u		// Screen Resolution
#define HRES	200u
#define lineSize	13

//--------------- Functions ---------------------
void initVGA(void);					// Inicialization of VGA module
void swapV(void);					// Swap video Buffers
void cleanHScreen(void);			// Clean hidden Buffer

// graphics (see graphics.c -- unchanged)
int readDotH(unsigned x, unsigned y);// Check a pixel in the Hidden Buffer
int readDotA(unsigned x, unsigned y);// Check a pixel in the Active Buffer

void plotDot(unsigned x, unsigned y,// Light up one pixel at cord.
				 unsigned color);

void plotLine(   int x0, int y0,  	// plot a line
 			     int x1, int y1,
                 unsigned color);

void plotSquare( int x0, int y0, 	// plot a square
				 int x1, int y1,
				 unsigned filled,unsigned color);

void plotCircle( int x0, int y0, 	// plot a circle
				 int radius, int color);

// Free-running tick source for the cursor/piece blink (chessInterface.c),
// replacing the dsPIC's prescaled Timer1 (TMR1). Not part of the original
// VGA.h -- added here since VGA.c is where the platform timebase lives now.
unsigned long now_ticks(void);

//--------------- Variables ---------------------
extern volatile	int *VH ;			// Pointer to the hidden video buffer
extern volatile	int *VA ;			// Pointer to the active video buffer

#endif
