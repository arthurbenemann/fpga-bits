//------------------------------------------------
//		chessEngine.c
//	Arthur Benemann 
//						03/05/2011
//------------------------------------------------
//  
//	Description:
// This contains some important functions to the the chees
// engine.
//
// This files:
//	chessEngine.c
//	chessEvaluation.c
//	chessMakeMove.c
// 	chessMoveGen.c
//  chessSearch.c
//  chessTables.c
//
// Are the Chess Engine
//	
//-------------------------------------------------

#include "chessEngine.h"

#include <string.h> /* memcpy */

char board[128];

char Side;

TBoardST BoardStatus;

//------------------------------ PRIVATE PROTOTYPES --------------------------------
int testAttack(unsigned char pos,unsigned char color);


//--------------------------------- FUNCTIONS --------------------------------------

//--------------------------- initBoard --------------------------------------------
// Initilize the board with the standart 
// start position of chess
void initBoard()
{
	memcpy(board, startBoard, sizeof(board));	// copy starting layout
	BoardStatus.Castle = CASTLE_ALL;			// Both player can castle in the beggining
	Side = White;								// White pieces play first			
	moveStackPtr = moveStack;					// Move stack in the bottom of the pile
}

//-------------------- BSType ----------------------
// returns the piece type for a board square index
int BSType(int pos)
{
	if(board[pos]!=empty)
		return (board[board[pos]+DELTA_TYPE]);
	else
		return empty;
}


//------------- checkCastle --------------
// Check if move is a castle atempt,
// and return castle Status for the move
unsigned checkCastle(MOVE m)
{
	int kingPos,side;
	if((BSType(m.from)&PIECE_MASK)==king)			// castle can only be done by my]oving the king
	{
		side = SideOfBS(m.from);					// save side that is moving
		kingPos=(side == Black)?0x74:0x04;			// Get initial king position
		if(m.from == kingPos)						// King must be on starting square
		{
			if((m.to == kingPos + 0x02))			// Kingside Castling
				return ((side == Black)?CASTLE_BK:CASTLE_WK);
			if((m.to == kingPos - 0x02))			// Queenside Castling
				return ((side == Black)?CASTLE_BQ:CASTLE_WQ);

		}
	}
	return CASTLE_NONE;								// if was not a castle attept return 0 castle status
}

//--------------------------- kingIsInCheck --------------------------------------
// Checks if theng of the side passed as arg. is in check,
// return TRUE for check, FALSE for not checked
int kingIsInCheck(int side)
{
	int kingPos;
	
	kingPos = (side)?					// get king position
			board[KING_POS+DELTA_POINTER+BLACK_POS]:				
			board[KING_POS+DELTA_POINTER];

	return (testAttack(kingPos,!side));	// check if king square is attacked by the oposite side
}


//----------------------------- testMove ------------------------------------------
// Test if move is valid by chess rules
int testMove(MOVE m)
{
	moveStackPtr = moveStack;			// Reset pointer to the bottom of the stack

	genMoves(Side);						// Generetes valid moves, stacking them on the moveStack

	while(moveStackPtr-- != moveStack)	// While there are moves on the stack, keep looping thought them
	{									
		if(CompareMoves(m,*moveStackPtr))
		{
			moveStackPtr = moveStack;	// Reset pointer to the bottom of the stack
			return TRUE;				// If move is in the list, it is valid
		}
	}
	moveStackPtr = moveStack;			// Reset pointer to the bottom of the stack
	return FALSE;						// if not, it is not valid
}




//------------------ testAttack ----------------------------
// tests if there is at least one piece of the color
// passed as arg. attacking some pos in the board.
int testAttack(unsigned char pos,unsigned char color)
{
	int i,j,k,w;
	
	// Load up initial with Piece Pointers for the attacker
	i=(color)?DELTA_POINTER+BLACK_POS:DELTA_POINTER;	

	// run trought all enemy pice pointers
	for(j=0; j<2; j++,i+=DELTA_POINTER)					
		while(IsOffBoard(i))								
		{
		if((board[i])!= PP_EMPTY)				   // skip captured pieces
			switch(board[i+DELTA_TYPE]&PIECE_MASK)	// get attacker type
			{
				case pawn://---------------------------------------------- Pawn 
					if(color == Black)						// Pawn attack direction depens on collor
					{
						if(pos==board[i]-0x11)				// check for attack on the diagonals
							return TRUE;
						if(pos==board[i]-0x0F)
							return TRUE;
					}
					else
					{										// check for attack on the diagonals
						if(pos==board[i]+0x11)
							return TRUE;
						if(pos==board[i]+0x0F)
							return TRUE;
					}
					break;				
		    	case queen://--------------------------------------------- Queen attack
					// Queen = Bishop + Rook. So this can be done testing for Bishop and Rook attacks
					// Quen fall through bishops moves up to the rooks attack
				case bishop://-------------------------------------------- Bishop attack		
					for(k=0; k<sizeof(movesBishop); k++)	// test for bishop attacks
						for(w=board[i]+movesBishop[k];    	// sliding bishop in each direction
							 IsOnBoard(w); w+=movesBishop[k]) // until it kicks someone
						{
							if(pos == w)					// if gets to 'pos' attack it's attacking
								return TRUE;			
							if(board[w] != empty)			// can't go any further in this direction if 
								break;						// if finds a piece in the way
						}
					if((board[i+DELTA_TYPE]&PIECE_MASK)==bishop)// in case of a bishop attack test ends here,
						break;								// but a queen must go ahead trought rook attacks	
		    	case rook://----------------------------------------------- Rook attack
					for(k=0; k<sizeof(movesRook); k++)		// test for rook attacks
						for(w=board[i]+movesRook[k];    	// sliding rook in each direction
							 IsOnBoard(w); w+=movesRook[k]) // until it kikcs someone
						{
							if(pos == w)					// if gets to 'pos' attack it's attacking
								return TRUE;			
							if(board[w] != empty)			// can't go any further in this direction if 
								break;						// if finds a piece in the way
						}
					break;				
		    	case king://----------------------------------------------- King attack
					for(k=0; k<sizeof(movesKing); k++)		// test for king attacks
						if(pos == (board[i] + movesKing[k]))
							return TRUE;
					break;
   				case knight://-------------------------------------------- Knight 
					for(k=0; k<sizeof(movesKnight); k++)	// test for knight attacks
						if(pos == (board[i] + movesKnight[k]))
								return TRUE;
					break;
				default:
					break;
			}
			i++;		// goto next enemy piece
		}
	return FALSE;
}

