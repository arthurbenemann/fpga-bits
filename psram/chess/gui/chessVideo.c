//--------------------------------------------------------
//		chessVideo.c
//	Arthur Benemann 03/05/2010
//--------------------------------------------------------
//
//	Description:
//	functions used by the chess engine to draw
//  on the screen.
//
//--------------------------------------------------------
//------------------ INCLUDEs ----------------------------
#include "chessSet.h"		// Pieces Bitmaps
#include "chessEngine.h"	// Board definitions
#include "chessInterface.h"	// Inteface functions

#include "VGA.h"           // Video Screen Buffers (our shim, on the real framebuffer -- see chess/vga/)
#include "text.h"          // Video text

#include "clock.h"         // for getTime() -- no RTC on this board, stub (see chess/vga/clock.h)

//------------------ MACROS -----------------------------
#define squareIsWhite(P) (((P>>4)+(P&COL_MASK))&0x1)
#define squareIsBlack(P) (!squareIsWhite(P))

#define pieceColor(P)    (P & BLACK_POS)
#define pieceIsBlack(P)	 (pieceColor(P))
#define pieceIsWhite(P)  (!pieceIsBlack(P))

#define posToVideoPtr(pos)	VH   +\
       			   (pos&COL_MASK)+\
  (lineSize*(0x70-(pos&ROW_MASK)));

//----------------- DEFINITONS --------------------------
//Size of the promotion box
#define PROMO_X		90 	
#define PROMO_Y		64
//Cordinates of the promotion box
#define PROMO_X0	(HRES-PROMO_X)/2
#define PROMO_Y0	(VRES-PROMO_Y)/2

//Size of the Game Type box
#define TYPE_X		90 	
#define TYPE_Y		64
//Cordinates of the Game Type box
#define TYPE_X0		(HRES-TYPE_X)/2
#define TYPE_Y0		(VRES-TYPE_Y)/2

//Size of the Game Level box
#define LEVEL_X		120 	
#define LEVEL_Y		64
//Cordinates of the Game Level box
#define LEVEL_X0		(HRES-LEVEL_X)/2
#define LEVEL_Y0		(VRES-LEVEL_Y)/2
// Delta to add to the cursor in the Level box
#define LEVEL_CURSOR	(-15)

//Size of the Overflow box
#define OVERF_X		90 	
#define OVERF_Y		20
//Cordinates of the Overflow box
#define OVERF_X0	(HRES-OVERF_X)/2
#define OVERF_Y0	(VRES-OVERF_Y)/2

// Cordinates of the Move list
#define LIST_X0 	(BOARD_SIZE+20)
#define LIST_Y0		(VRES-FONT_Y-2)

// Cordinates of the time
#define TIME_X0		(HRES-FONT_X*8-2)
#define TIME_Y0		1


// Cursor Pos, and spacing
#define CURSOR_X	(PROMO_X0+13)
#define CURSOR_Y    (PROMO_Y0+PROMO_Y-24)
#define CURSOR_LINE (9) 



//----------------- FUNCTIONs ---------------------------

//------------------ plotBoard --------------------------
// Plots the board in the video buffer
void plotBoard()
{
	int i,j,pos,type;

	plotAlgNotation();

	for(j=0;j<8;j++)
		for(i=0;i<8;i++)
		{
			pos   = j*0x10+i;
			type=BSType(pos);
			plotPiece(pos,type);
		}
}

//----------------- plotMoveList -----------------------
// Display all moves in a list on the side of the board
void plotMoveList(void)
{
	char buf[10];
	
	int i,k;
	i = firstML;
	putsV("MOVES:",LIST_X0,LIST_Y0);
	k = LIST_Y0 -FONT_Y -1;
	while(i != endML)	// run troght all the list		
	{

		moveToStr(moveList[i],buf);				// convert move to a string
		putsV(buf,LIST_X0+2,k);					// and paint the string
		
		i =(i+1) % MOVELIST_SIZE;				// goto next move
		k-= FONT_Y;								// advance Line
	}
}

//----------------plotChessSplash------------------------
// Plots a Splash Screen for the chess game
void plotChessSplash(void)
{
	volatile int *VideoPtr;
	const int *PiecePtr;
	int i;

	cleanHScreen();				// Clean Video Buffer

	putsV("picChess v1.0",44,90);
	putsV("by Arthur Benemann",50,9);
	putsV("Jun 13 2011",106,0);	// was __DATE__: keep the original build era

	// Start the bitmap transfer at the correct board position
	VideoPtr = posToVideoPtr(0x41);
	// Load up the bitmap
	PiecePtr = _knightBitmap;

	// Transfer the bitmap
	for(i=0; i<16;i++)
	{	
		*VideoPtr = ~*PiecePtr;
		*(VideoPtr+9) = ~*PiecePtr++;
		VideoPtr += lineSize;
	}	

	swapV();
}

//----------------plotAlgNotation -----------------------
// print the algelgric notation ranks and files,
// on the border of the board, and a outside border
void plotAlgNotation()
{
	int i;
	for(i=0; i<8; i++)
	{
		// Vertical files
		putV(i+'a',4+(i<<4),VRES-BOARD_SIZE-9);			
		// Horizontal ranks
		putV(i+'1',BOARD_SIZE,VRES-BOARD_SIZE+4+(i<<4));
	}
	
	// Draw Outside Border
	plotSquare(-1,VRES-BOARD_SIZE-10,BOARD_SIZE+9,VRES,0,1);
}

//------------------ plotPromoBox -----------------------
// Plots the pawn promotion box, with cursor pos
// indicated by the argument
void plotPromoBox(int cursorPos)
{
	// Clear memory map behind promo box with a blank square
	plotSquare(PROMO_X0,        PROMO_Y0,
			   PROMO_X0+PROMO_X,PROMO_Y0+PROMO_Y,
				1,0);
	// Draw Outside Border
	plotSquare(PROMO_X0,        PROMO_Y0,
			   PROMO_X0+PROMO_X,PROMO_Y0+PROMO_Y,
				0,1);
	plotSquare(PROMO_X0+2,      PROMO_Y0+2,
			   PROMO_X0+PROMO_X-2,PROMO_Y0+PROMO_Y-2,
				0,1);

	// Place text
	putsV("Promotion:",PROMO_X0+5, PROMO_Y0+PROMO_Y-5-FONT_Y);
	putsV("Queen",     PROMO_X0+20,PROMO_Y0+PROMO_Y-10-9*2);
	putsV("Rook",      PROMO_X0+20,PROMO_Y0+PROMO_Y-10-9*3);
	putsV("Bishop",    PROMO_X0+20,PROMO_Y0+PROMO_Y-10-9*4);
	putsV("Knight",    PROMO_X0+20,PROMO_Y0+PROMO_Y-10-9*5);

	// Place the cursor
	cursorPos &= 0x3;	// But keep it in range first
	plotSquare(CURSOR_X,  CURSOR_Y-CURSOR_LINE*cursorPos,
			   CURSOR_X+2,CURSOR_Y-CURSOR_LINE*cursorPos+2,
		   	   0,1);
}

//------------------ plotGameTypeBox -----------------------
// Plots the Game type selection box, with cursor pos
// indicated by the argument
void plotGameTypeBox(int cursorPos)
{
	// Clear memory map behind promo box with a blank square
	plotSquare(TYPE_X0,        TYPE_Y0,
			   TYPE_X0+TYPE_X,TYPE_Y0+TYPE_Y,
				1,0);
	// Draw Outside Border
	plotSquare(TYPE_X0,        TYPE_Y0,
			   TYPE_X0+TYPE_X,TYPE_Y0+TYPE_Y,
				0,1);
	plotSquare(TYPE_X0+2,      TYPE_Y0+2,
			   TYPE_X0+TYPE_X-2,TYPE_Y0+TYPE_Y-2,
				0,1);

	// Place text
	putsV("Game Type:",TYPE_X0+5, TYPE_Y0+TYPE_Y-5-FONT_Y);
	putsV("PvP", 	   TYPE_X0+20,TYPE_Y0+TYPE_Y-10-9*2);
	putsV("PvC",       TYPE_X0+20,TYPE_Y0+TYPE_Y-10-9*3);
	putsV("CvP",       TYPE_X0+20,TYPE_Y0+TYPE_Y-10-9*4);
	putsV("CvC",       TYPE_X0+20,TYPE_Y0+TYPE_Y-10-9*5);

	// Place the cursor
	cursorPos &= 0x3;	// But keep it in range first
	plotSquare(CURSOR_X,  CURSOR_Y-CURSOR_LINE*cursorPos,
			   CURSOR_X+2,CURSOR_Y-CURSOR_LINE*cursorPos+2,
		   	   0,1);
}

//------------------ plotGameLevelBox -----------------------
// Plots the game level Select box, with cursor pos
// indicated by the argument
void plotGameLevelBox(int cursorPos)
{
	// Clear memory map behind promo box with a blank square
	plotSquare(LEVEL_X0,        LEVEL_Y0,
			   LEVEL_X0+LEVEL_X,LEVEL_Y0+LEVEL_Y,
				1,0);
	// Draw Outside Border
	plotSquare(LEVEL_X0,        LEVEL_Y0,
			   LEVEL_X0+LEVEL_X,LEVEL_Y0+LEVEL_Y,
				0,1);
	plotSquare(LEVEL_X0+2,      LEVEL_Y0+2,
			   LEVEL_X0+LEVEL_X-2,LEVEL_Y0+LEVEL_Y-2,
				0,1);

	// Place text
	putsV("Game Deep:", LEVEL_X0+5, LEVEL_Y0+LEVEL_Y-5-FONT_Y);
	putsV("Easy    (3)",LEVEL_X0+20,LEVEL_Y0+LEVEL_Y-10-9*2);
	putsV("Medium  (4)",LEVEL_X0+20,LEVEL_Y0+LEVEL_Y-10-9*3);
	putsV("Hard    (5)",LEVEL_X0+20,LEVEL_Y0+LEVEL_Y-10-9*4);
	putsV("Suicide (6)",LEVEL_X0+20,LEVEL_Y0+LEVEL_Y-10-9*5);

	// Place the cursor
	cursorPos &= 0x3;	// But keep it in range first
	plotSquare(CURSOR_X+LEVEL_CURSOR,  CURSOR_Y-CURSOR_LINE*cursorPos,
			   CURSOR_X+2+LEVEL_CURSOR,CURSOR_Y-CURSOR_LINE*cursorPos+2,
		   	   0,1);
}


//------------------ plotOverflowBox -----------------------
// Plots the overflow box
void plotOverflowBox(void)
{
	// Clear memory map behind promo box with a blank square
	plotSquare(OVERF_X0,        OVERF_Y0,
			   OVERF_X0+OVERF_X,OVERF_Y0+OVERF_Y,
				1,0);
	// Draw Outside Border
	plotSquare(OVERF_X0,        OVERF_Y0,
			   OVERF_X0+OVERF_X,OVERF_Y0+OVERF_Y,
				0,1);
	plotSquare(OVERF_X0+2,      OVERF_Y0+2,
			   OVERF_X0+OVERF_X-2,OVERF_Y0+OVERF_Y-2,
				0,1);

	// Place text
	putsV("Overflow !",OVERF_X0+5, OVERF_Y0+OVERF_Y-5-FONT_Y);
	swapV();
}

//------------------ plotPiece --------------------------
// Plot a chess piece on the correct position for 
// a 128x128 board on the video buffer. Pieces bitmaps
// are stored in constant arrays on the file chessSet.c
void plotPiece(char pos,char piece)
{
	int i;
	volatile int *VideoPtr;
	const int *PiecePtr;	

	// Select bitmap based on the piece code color and square color
	i = pieceIsBlack(piece);
	i = squareIsWhite(pos);

	if(pieceIsWhite(piece)!= squareIsBlack(pos))
		switch(piece & PIECE_MASK)
		{
			case pawn:
				PiecePtr = pawnBitmap;
				break;
			case knight:
				PiecePtr = knightBitmap;
				break;
			case king:
				PiecePtr = kingBitmap;
				break;
			case bishop:
				PiecePtr = bishopBitmap;
				break;
			case rook:
				PiecePtr = rookBitmap;
				break;
			case queen:
				PiecePtr = queenBitmap;
				break;	
			default:
			case empty:
				PiecePtr = blankBitmap;
				break;
		}
	else
		switch(piece & PIECE_MASK)
		{
			case pawn:
				PiecePtr = _pawnBitmap;
				break;
			case knight:
				PiecePtr = _knightBitmap;
				break;
			case king:
				PiecePtr = _kingBitmap;
				break;
			case bishop:
				PiecePtr = _bishopBitmap;
				break;
			case rook:
				PiecePtr = _rookBitmap;
				break;
			case queen:
				PiecePtr = _queenBitmap;
				break;	
			default:
			case empty:
				PiecePtr = _blankBitmap;
				break;
		}

	// Start the bitmap transfer at the correct board position
	VideoPtr = posToVideoPtr(pos);


	// Transfer the bitmap
	if(pieceIsBlack(piece))
		for(i=0; i<16;i++)
		{	
			*VideoPtr = *PiecePtr++;
			VideoPtr += lineSize;
		}
	else
		for(i=0; i<16;i++)
		{	
			*VideoPtr = ~*PiecePtr++;
			VideoPtr += lineSize;
		}
}

//--------------------- PlotTime --------------------------
// Plot the current time in the left down corner 
void plotTime(void)
{
	char str[10];
	getTime(str);				// gets the time
	putsV(str,TIME_X0,TIME_Y0);	// put it on the screen
}

//---------------------- Plot Cursor ----------------------
// Plots a cursor over the image of the board on the 
// video buffer. The cursor is just 4 squares (2x2)
// on the corners of a piece of the chess board.
// Cursor color is the oposite of the square color.
void plotCursor(char pos)
{
	volatile int *VideoPtr;

	// Setup a pointer to the video map
	VideoPtr = posToVideoPtr(pos);		

	// Paint the cursor over the board image
	if(squareIsWhite(pos))
	{	// White Square
		*(VideoPtr)&= CURSOR_MASK;		//fisrt to lines
		VideoPtr   += lineSize;
		*(VideoPtr)&= CURSOR_MASK;
		VideoPtr   += 13*lineSize;		// jump to last two
		*(VideoPtr)&= CURSOR_MASK;		
		VideoPtr   += lineSize;
		*(VideoPtr)&= CURSOR_MASK;		// end line (15)
	}
	else
	{	// Black Square
		*(VideoPtr)|= ~CURSOR_MASK;		//fisrt to lines
		VideoPtr   += lineSize;
		*(VideoPtr)|= ~CURSOR_MASK;
		VideoPtr   += 13*lineSize;		// jump to last two
		*(VideoPtr)|= ~CURSOR_MASK;		
		VideoPtr   += lineSize;
		*(VideoPtr)|= ~CURSOR_MASK;		// end line (15)
	}
}
