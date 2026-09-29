//------------------------------------------------
//		chessMoveGen.c
//	Arthur Benemann 
//						18/05/2011
//------------------------------------------------
//  
//	Description:
//	Generetes all valid chess moves from the current state of the 
//	board. Moves are saved in order in the moveStack, at the address 
//	pointed by the moveStackPtr.
//
//-------------------------------------------------

#include "chessEngine.h"
#include <stdlib.h>
//---------------------------------- VARIABLES -------------------------------------
MOVE	moveStack[MAX_STACK];	// Moves stack
MOVE	*moveStackPtr;			// first empty entry in the move stack
MOVE	*moveStackEnd = 		// last entry of the stack
		 moveStack+MAX_STACK-1;
//------------------------------ PRIVATE PROTOTYPES --------------------------------
int testMoveForCheck(MOVE m,int side);
int pushPawnMove(MOVE m, int side);
void pushMove(MOVE *m);

int quickScore(MOVE *m){
	int score;
	
	if(board[m->to]!=empty)
		score = board[m->to]*queen - board[m->from]; 
	else
		score = 0;

	return score;
}

int moveCmp(const void *a, const void *b){
	return quickScore((MOVE *)a) - quickScore((MOVE *)b); // a and b reversed so sortingis in descending scores
}


//--------------------------------- FUNCTIONS --------------------------------------

int genMovesOrdered(unsigned char side){
	int genCnt;
	MOVE *first;

	first = moveStackPtr;
	genCnt = genMoves(side);

	qsort(first,genCnt,sizeof(MOVE), moveCmp);
	return genCnt;
}

//--------------------- genMoves -------------------
// Generates all valid moves one player in the current
// position. Each valid move is saved on the moveStack.
// Returns the number of moves generated.
int genMoves(unsigned char side)
{
	int movCount = 0;
	int i,j,k;
	MOVE m;

	// run trought all piece pointers
	for(j=15; j>=0; j--)					
	{
		i=genOrder[j];
		if(side == Black)
			i+=BLACK_POS;
		if(board[i] != PP_EMPTY)					// skip eated pieces
			switch(board[i+DELTA_TYPE]&PIECE_MASK)	// get attacker type
			{
				case pawn: //---------------------------------------------- Pawn 
					m.from = 0;
					int pawnAdv,row2;
					m.from = board[i];
					m.eat  = empty;
					m.status.st = 0;
					if(side ){
						pawnAdv =-0x10;
						row2    = 0x60;
					}else {
						pawnAdv = 0x10;
						row2    = 0x10;
					}		
					if(IsOnBoard((m.to=m.from+pawnAdv)))	// test if sigle pawn advance is on board
						if(board[m.to] == empty)  			// square in front of pawn must be empty
						{
							movCount+=pushPawnMove(m,side);

							if((m.from&ROW_MASK)== row2)		//  if is on Row2 try double advance
								if(IsOnBoard((m.to += pawnAdv)))
									if(board[m.to] == empty)	// both squares in front of pawn must be empty								
										movCount+=pushPawnMove(m,side);
						} // pawnAdvances


					if(IsOnBoard((m.to=m.from+pawnAdv+0x01)))	// test if pawn capture is on board
						if(board[m.to])							// 	square must not be empty
							if(SideOfBS(m.to)!=side)  			// square in the right digonal must have a enemy piece
							{
								m.eat  = board[m.to];			// valid eat
								movCount+=pushPawnMove(m,side);
							}
					if(IsOnBoard((m.to=m.from+pawnAdv-0x01)))// test if pawn capture is on board
						if(board[m.to])							// 	square must not be empty
							if(SideOfBS(m.to)!=side)  			// square in the left digonal must have a enemy piece
							{
										m.eat  = board[m.to];	// valid eat
										movCount+=pushPawnMove(m,side);
							}

					break;	
		
		    	case queen://--------------------------------------------- Queen attack
					// Queen = Bishop + Rook. So this can be done testing for Bishop and Rook moves
					// Quen fall through bishops moves up to the rooks moves
		    	case bishop://----------------------------------------------- Bishop attack
					for(k=0; k<sizeof(movesBishop); k++)		// test for Bishop attacks
					   for(m.to=board[i]+movesBishop[k],m.eat=0;// sliding bishop in each direction
		    				   (IsOnBoard(m.to) && (m.eat==0));	// until it goes of board
										  m.to+=movesBishop[k])	// or eats someone ( or hits frindly piece)
						{
							m.from = 0xff;						// used as invalid move flag				
							m.status.st = 0;
								if(board[m.to]){				// check if empty, ( hit or eat if not)
									if(SideOfBS(m.to)!=side)	// On filled squares, check if is a enemy piece
									{ // hit
										m.from = board[i];	
										m.eat  = board[m.to];	// valid eat
									}
									else
										m.eat  = 0xff;			// Just flag for a hit										 
								}
								else
									m.from = board[i];			// valid move

								if(m.from!=0xff)
									if(testMoveForCheck(m,side))
									{
										pushMove(&m);
										movCount++;
									}
						}//bishopMoves
					if((board[i+DELTA_TYPE]&PIECE_MASK)==bishop)// in case of a bishop attack test ends here,
						break;									// but a queen must go ahead trought rook attacks
				
		    	case rook://----------------------------------------------- Rook attack
					for(k=0; k<sizeof(movesRook); k++)			// test for rook attacks
						for(m.to=board[i]+movesRook[k],m.eat=0;	// sliding rook in each direction
		    				   (IsOnBoard(m.to) && (m.eat==0));	// until it goes of board
											m.to+=movesRook[k])	// or eats someone ( or hits frindly piece)
						{
							m.from = 0xff;						// used as invalid move flag				
							m.status.st = 0;
								if(board[m.to]){				// check if empty, ( hit or eat if not)
									if(SideOfBS(m.to)!=side)	// On filled squares, check if is a enemy piece
									{ // hit
										m.from = board[i];	
										m.eat  = board[m.to];	// valid eat
									}
									else
										m.eat  = 0xff;			// Just flag for a hit										 
								}
								else
									m.from = board[i];			// valid move

								if(m.from!=0xff)
									if(testMoveForCheck(m,side))
									{
										pushMove(&m);
										movCount++;
									}
						}//rookMoves
					break;

		    	case king://----------------------------------------------- King attack
					for(k=0; k<sizeof(movesKing); k++)	// test for king moves
					{
						m.to = board[i] + movesKing[k];
						m.from = 0xff;						// used as invalid move flag				
						m.eat  = 0;
						m.status.st = 0;
						if(IsOnBoard(m.to)){				// check if generated position is on board
							if(board[m.to]){				// check if empty
								if(SideOfBS(m.to)!=side){	// On filled squares, check if is a enemy piece
									m.from = board[i];	
									m.eat  = board[m.to];	// valid eat
								} 
							}
							else
								m.from = board[i];			// valid move
							if(m.from!=0xff)
								if(testMoveForCheck(m,side))
								{
									pushMove(&m);
									movCount++;
								}
						}//on board
					}//kingMoves

					if(BoardStatus.Castle) 							// Castling 		
					{	
						int kingPos,kingCastleMask,queenCastleMask;
						if(side){ // black
							kingPos         = BKING_POS;
							kingCastleMask  = CASTLE_BK;
							queenCastleMask = CASTLE_BQ;
						}		
						else	{// White
							kingPos         = KING_POS;
							kingCastleMask  = CASTLE_WK;
							queenCastleMask = CASTLE_WQ;
						}

						if(!testAttack(kingPos,!side))	   	  		// king must not be in check for castling.
							{
								if(BoardStatus.Castle&kingCastleMask)// Check for kingSide Castling Right
									if(	
								    !testAttack(kingPos+0x1,!side)&& // king does not pass through a attacked square
									(board[kingPos+0x01] == empty)&& // check for free passage.
									(board[kingPos+0x02] == empty) )
										{
											m.from = kingPos;
											m.to   = kingPos + 0x02;
											m.eat  = 0x00;
											m.status.promotion = 0;
											m.status.Castle=kingCastleMask; 
											if(testMoveForCheck(m,side))
											{
												pushMove(&m);;
												movCount++;			
											}
										} // Kingside Castle
								if(BoardStatus.Castle&queenCastleMask) // Check for quennSide Castling Right
									if(	
								    !testAttack(kingPos-0x1,!side)  && // king does not pass through a attacked square
									(board[kingPos-0x01] == empty)  && // check for free passage.
									(board[kingPos-0x02] == empty)  && 
									(board[kingPos-0x03] == empty)   )
										{
											m.from = kingPos;
											m.to   = kingPos - 0x02;
											m.eat  = 0x00;
											m.status.promotion = 0;
											m.status.Castle=queenCastleMask; 
											if(testMoveForCheck(m,side))
											{
												pushMove(&m);
												movCount++;	
											}				
										} // Queenside Castle
							}// castle
					}// Castling 

					break;

  				case knight://-------------------------------------------- Knight 
					for(k=0; k<sizeof(movesKnight); k++)	// test for knight moves
					{
						m.to = board[i] + movesKnight[k];
						m.from = 0xff;						// used as invalid move flag				
						m.eat  = 0;
						m.status.st = 0;
						if(IsOnBoard(m.to)){				// check if generated position is on board
							if(board[m.to]){				// check if empty
								if(SideOfBS(m.to)!=side){	// On filled squares, check if is a enemy piece
									m.from = board[i];	
									m.eat  = board[m.to];	// valid eat
								} 
							}
							else
								m.from = board[i];			// valid move
							if(m.from!=0xff)
								if(testMoveForCheck(m,side))
								{
									pushMove(&m);
									movCount++;
								}
						}//on board
					}//knightMoves
					break; 
				default: //--------------------------------------------- movesEnd
					break;
			}
		}// run trough all pieces
	
	return movCount;
}

//--------------------- pushMove -------------------
// Adds one move to the stack.
// returns false if overflow
void pushMove(MOVE *m)
{
	
	if(moveStackPtr<moveStackEnd)	// check for ovewflow
	{
		*moveStackPtr++ = *m;		// else add one entry to the stack
		return;
	}

	//errorOverflow();
	while(1);
	return;
}

//------------------- pushPawnPromo ---------------
// test if move is a pawn promotion
// and then pushes all the possible
// promotions for a pawn move or a simple moves.
int pushPawnMove(MOVE m, int side)
{
	int movCount = 0;
	int lastRow;
	m.status.st = empty;
	if(testMoveForCheck(m,side))	// test if move does not make king in check 
	{	
		lastRow = (side)? 0x00:0x70;
		if((m.to&ROW_MASK)==lastRow)// must test if is a promotion
		{							// promotion add 4 diferent moves
			m.status.promotion=queen;
			pushMove(&m);
			movCount++;
			m.status.promotion=knight;
			pushMove(&m);
			movCount++;
			m.status.promotion=rook;
			pushMove(&m);
			movCount++;
			m.status.promotion=bishop;
			pushMove(&m);
			movCount++;
		}
		else
		{							// for normal moves just save in the stack
			pushMove(&m);
			movCount++;
		}
	}							
	return movCount;
}

//-------------- testMoveForCheck()-----------------------
// test if after making the move the king won't be in check
// only works if Side == player that will make the move
int testMoveForCheck(MOVE m,int side)
{
	int flag,kingPos,sideTemp;
	int castleTemp = BoardStatus.Castle;			// make the move and
	sideTemp = Side; Side = side;	

	makeMove(m);									// side change when making a move
	kingPos=(!Side)?								// get king pos after move
		board[KING_POS+DELTA_POINTER+BLACK_POS]:				
		board[KING_POS+DELTA_POINTER];
	flag = !testAttack(kingPos,Side);				// test if move doesn't check the king
	unMakeMove(m);									
	BoardStatus.Castle = castleTemp;				// undo the move
	Side = sideTemp;
	return flag;
}
