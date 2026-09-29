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


#define FONT_X		8		// Horizoltal size of the FONT
#define FONT_Y		8		// Vertical size of the FONT

typedef struct {
		unsigned char x:4;
		unsigned char y:4;
	} cord; 


void putV(unsigned char c,unsigned char x,unsigned char y);
int putsV(char *c,unsigned char x,unsigned char y);

