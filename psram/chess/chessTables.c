//------------------------------------------------
//		chessTable.c
//	Arthur Benemann 
//						18/05/2011
//------------------------------------------------
//  
//	Description:
//	Tables utilized by the chess engine.
//
//  Moves Tables
//  Initial board state
//  Piece Values
//  Gen. Ordering
//
//-------------------------------------------------
//
//	Board Representation:
//
//	Board 0x88: 
//	
//	-----------------------------------------------------
//	| 70 71 72 73 74 75 76 77 | 78 79 7A 7B 7C 7D 7E 7F |
//	| 60 61 62 63 64 65 66 67 | 68 69 6A 6B 6C 6D 6E 6F |
//	| 50 51 52 53 54 55 56 57 | 58 59 5A 5B 5C 5D 5E 5F |
//	| 40 41 42 43 44 45 46 47 | 48 49 4A 4B 4C 4D 4E 4F |
//	| 30 31 32 33 34 35 36 37 | 38 39 3A 3B 3C 3D 3E 3F |
//	| 20 21 22 23 24 25 26 27 | 28 29 2A 2B 2C 2D 2E 2F |
//	| 10 11 12 13 14 15 16 17 | 18 19 1A 1B 1C 1D 1E 1F |
//	| 00 01 02 03 04 05 06 07 | 08 09 0A 0B 0C 0D 0E 0F |
//	-----------------------------------------------------
//
//	-----------------------------------------------------
//	|						  |	Piece types	    		|
//	|						  |	(Black)		    		|
//	|						  |-------------------------|
//	|	  Board Square		  |	Piece Pointer		   	|
//	|						  |			(Black)	    	|
//	|			  			  |-------------------------|
//	|			 			  |	Piece types	    		|
//	|						  |	(white)		   			|
//	|						  |-------------------------|
//	|						  |	Piece Pointer		   	|
//	|						  |			(white)	    	|
//	-----------------------------------------------------
//
//		Piece pointers point to a Board Square if the piece is
//	on the game.(0xFF if not)
//		BoardSquares point to a Piece pointer if the piece is
//	on the game.(0x00 if not)
//		PieceTypes hold the type of that piece ( nessecary beacuse
//	of pawn promotions). Each piece type correspont to the start 
//	layout of the board.
//
//	movement deltas:
//	-----------------
//	| 1E 1F 20 21 22|
//	| 0E 0F 10 11 12|
//	| FE FF 00 01 02|
//	| EE EF F0 F1 F2|
//	| DE DF E0 E1 E2|
//	-----------------
//-----------------------------------------------------------


#include "chessEngine.h"


//  Moves Tables
const char movesKnight[8] ={0x12,0x21,0x1F,0x0E,0xEE,0xDF,0xE1,0xF2};
const char movesKing[8]   ={0x10,0x11,0x01,0xF1,0xF0,0xEF,0xFF,0x0F};
const char movesRook[4]   ={0x10,0X01,0XF0,0XFF};
const char movesBishop[4] ={0x11,0xF1,0xEF,0x0F};
const char movesQueen[8]  ={0x10,0x11,0x01,0xF1,0xF0,0xEF,0xFF,0x0F};

//  Initial board state
const char startBoard[128] = 
{
    0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,	// 0x00 - 0x1F
	0x00,0x01,0x02,0x03,0X04,0x05,0x06,0x07,
    0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F,
	0x10,0x11,0x12,0x13,0X14,0x15,0x16,0x17,

	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,	// 0x20 - 0x3F
    rook, knight, bishop, queen, king, bishop, knight, rook,
	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    pawn, pawn, pawn, pawn, pawn, pawn, pawn, pawn,

    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,	// 0x40 - 0x5F
	0x70,0x71,0x72,0x73,0X74,0x75,0x76,0x77,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
	0x60,0x61,0x62,0x63,0X64,0x65,0x66,0x67,

	0x58,0x59,0x5A,0x5B,0x5C,0x5D,0x5E,0x5F,	// 0x60 - 0x7F
    rook|BLACK_POS, knight|BLACK_POS, bishop|BLACK_POS, queen|BLACK_POS, king|BLACK_POS, bishop|BLACK_POS, knight|BLACK_POS, rook|BLACK_POS,
	0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,
    pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS, pawn|BLACK_POS,
};


// Piece Values
const int pieceValue[8] = {
		0, 		// empty
		100, 	// pawn
    	300, 	// knight
    	16380, 	// king
		0,
    	350, 	// bishop
    	500, 	// rook
    	950  	// queen
	};// pieceValues

// Gen. Ordering
const char genOrder[] ={
	0xb,	0xc,	0xa,	0xd,
	0x9,	0xe,	0x8,	0xf,
	0x1b,	0x1c,	0x1a,	0x1d,
	0x19,	0x1e,	0x18,	0x1f
	};
