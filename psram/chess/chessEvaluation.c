//------------------------------------------------
//		chessEvaluation.c
//	Arthur Benemann 
//						18/05/2011
//------------------------------------------------
//  
//	Description:
//		A simple evalution function 
//	The avaluation function returns a number representing the score of the
//  current board state. Positive is good for black, negative for white.
//
//-------------------------------------------------

#include "chessEngine.h"

//------------------------------ PRIVATE PROTOTYPES --------------------------------

//--------------------------------- FUNCTIONS --------------------------------------

//------------------------- evaluateBoard ----------------------------------
//  Returns a number representing the score of the current board
//  state. Positive is good for black, negative for white
int evaluateBoard(void)
{
	int i,j;
	int score = 0;

	// Start scanning White pieces
	i = DELTA_POINTER;	

	// run trought all piece pointers
	for(j=0; j<2; j++,i+=DELTA_POINTER)	
		while(IsOffBoard(i))
		{
			if((board[i])!= PP_EMPTY)				   // skip captured pieces
				switch(board[i+DELTA_TYPE]&PIECE_MASK){// get piece value
				case pawn:
					score -= pieceValue[pawn];
					break;
				case knight:
					score -= pieceValue[knight];
					break;
				case bishop:
					score -= pieceValue[bishop];
					break;
				case rook:
					score -= pieceValue[rook];
					break;
				case queen:
					score -= pieceValue[queen];
					break;
				case king:
					score -= pieceValue[king];
					break;
				default:
					break;
				}		
			i++;		// goto next piece
		}

	// Now scan Black pieces
	i = DELTA_POINTER+BLACK_POS;	

	// run trought all piece pointers
	for(j=0; j<2; j++,i+=DELTA_POINTER)	
		while(IsOffBoard(i))
		{
			if((board[i])!= PP_EMPTY)				   // skip captured pieces
				switch(board[i+DELTA_TYPE]&PIECE_MASK){// get piece value
				case pawn:
					score += pieceValue[pawn];
					break;
				case knight:
					score += pieceValue[knight];
					break;
				case bishop:
					score += pieceValue[bishop];
					break;
				case rook:
					score += pieceValue[rook];
					break;
				case queen:
					score += pieceValue[queen];
					break;
				case king:
					score += pieceValue[king];
					break;
				default:
					break;
				}		
			i++;		// goto next piece
		}

	return score;
}
