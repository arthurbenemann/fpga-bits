//----------------------------------------------
//				text.c
// 	Draw text on video
// 	Arthur Bemann 06/05/2011
//-----------------------------------------------
//
//	Description:
//	Draw letters and strings on the video buffer
//  on any position by using  Bit Block Transfer.
//  Uses font from "font.h".
//	Takes about 500 cycles per letter
//
//-----------------------------------------------
//
//	Requeriments:
//	1Kbyte of ROM
//
//-----------------------------------------------

#include "VGA.h"				// Video Buffer prototype
#include "font.h"				// Font bitmaps
#include "text.h"				// Self puplic functions

#define FALSE	0
#define TRUE 	!FALSE

//-------------- putsV -------------------------
// Print a string on te video buffer, at the cord.
// passed as arg. . Return True if the string fitted on the screen
int putsV(char *c,unsigned char x,unsigned char y)
{
	while(*c)
	{
		putV(*c++,x,y);
		x += 8;
		if(x >= (HRES-8))	// Limited to the right of the screen 
			return FALSE;
	}
	return TRUE;
}

//-------------- putV --------------------------
// Draw the image of an char in the cordinate
// passed as arg.
void putV(unsigned char c,unsigned char x,unsigned char y)
{
	volatile int *VideoPtr;
	char i, xMod;
	const unsigned char *fp;

	int k;

	// check if char is in range
	c -= F_OFFS;
	if(c > F_SIZE)	c = F_SIZE - 1;

	// check if Cordinates are in range
	if(x >= (HRES-8)) x = HRES-8;	// Limited to the right of the screen 
	if(y >= (VRES-8)) y = VRES-8;	// Limited to the top of the screen 

	// set pointer to the first char line in the font array
	fp = &Font8x8[c<<3];

	// set pointer to video buffer
	VideoPtr = VH + (VRES-8-y)*lineSize;
	VideoPtr+= x>>4;

	xMod = 8 - x%16;

	// Transfer the bitmap
	for(i=0; i<8;i++)
	{
		if(xMod >= 0)				// Test if is contained in a word
		{
			k = ~((0x00ff)<<xMod);
			*VideoPtr&=k;	// maskout background			
			*VideoPtr|= ((*fp++))<<xMod;
		}
		else						
		{							// if isn't, transfer occurs in two words
			k =~((0x00ff)>>(-xMod));
			*VideoPtr    &=k;
			k = (*fp)>>(-xMod);
			*VideoPtr    |=k;
			k =~((0x00ff)<<(16+xMod));
			*(VideoPtr+1)&=k;
			k =(*fp++)<<(16+xMod);
			*(VideoPtr+1)|=k;
		}
		VideoPtr += lineSize;		// transfer next char bitmap line
	}
}
