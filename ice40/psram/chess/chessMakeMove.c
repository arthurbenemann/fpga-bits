//------------------------------------------------
//		chessMakeMove.c
//	Arthur Benemann 
//						12/05/2011
//------------------------------------------------
//  
//	Description:
//	Has two functions of extreme importance for the
//	chess engine:
//
//	makeMove(MOVE m)  -> makes the move on the board
//	unMakeMove(MOVE m)-> undo one move on  on the board
//
//	(obs.: unMakeMove doesn't undo the castling rights)
//
//-------------------------------------------------

#include "chessEngine.h"
	
//------------------------------ PRIVATE PROTOTYPES --------------------------------
void makeCastle(MOVE m);
void unMakeCastle(MOVE m);
void updateCastlingRights(MOVE m);

//--------------------------------- FUNCTIONS --------------------------------------
//------------------------------- makeMove -------------------------------
// Make the move passed as arg in the board. 
// Assumes that the move is valid.
void makeMove(MOVE m)
{
	if(m.status.Castle)							// in case of a king move must check for castling
		makeCastle(m);

	updateCastlingRights(m);					// Update Board castling rights when making this move	

	if(m.status.promotion)						// Check for promotion move
	{
		board[BSPT(m.from)]&=~PIECE_MASK;		// clean piece type
		board[BSPT(m.from)]|=m.status.promotion;// add new piece type
	}

	if( board[m.to] != empty )					// check if is eating a piece
			BSPP(m.to) =PP_EMPTY;				// if so, clear the eaten Piece Pointer

	BSPP(m.from)= m.to;							// adjust the moving piece pointer
	board[m.to]   = board[m.from];				// Move the piece
	board[m.from] =	empty;						// and clear the place from where it left

    Side = !Side;                               // switch sides after move
}


//------------------------------ makeCastle ----------------------------
// Makes a Castle. Assumes that the move is valid
void makeCastle(MOVE m)
{
	int kingPos;
	kingPos =(m.status.Castle & CASTLE_COLOR)?0x74:0x04;

	if(m.status.Castle & CASTLE_K)
	{	// Make kingside Castling
		BSPP(kingPos+0x03)  = kingPos+0x01;				// adjust the moving piece pointer
		board[kingPos+0x01] = board[kingPos+0x03];		// Move the rook
		board[kingPos+0x03] = empty;					// and clear board corner
	}	
	else 	
	{	// Make queenside Castling
		BSPP(kingPos-0x04)  = kingPos-0x01;				// adjust the moving piece pointer
		board[kingPos-0x01] = board[kingPos-0x04];		// Move the rook
		board[kingPos-0x04] = empty;					// and clear board corner
	}	
	
	if(m.status.Castle & CASTLE_COLOR)	                // side that castle lose castling rights
		BoardStatus.Castle &= ~CASTLE_COLOR;
	else
		BoardStatus.Castle &= ~CASTLE_COLOR_W;
}

//------------------------ updateCastlingRights ---------------------------
// Update Board Castling rights when a move is made
void updateCastlingRights(MOVE m)
{
 	int pieceType = BSType(m.from);

	if(pieceType == king)				// move the king also makes it lose castling rights
		BoardStatus.Castle &= ~CASTLE_COLOR_W;
	if(pieceType == (king|BLACK_POS))				
		BoardStatus.Castle &= ~CASTLE_COLOR;
	
	if(pieceType == rook)				// rook moves makes it lose castling rights
		{
			if(m.from==0x00)
				BoardStatus.whiteQ = 0;
			if(m.from==0x07)
				BoardStatus.whiteK = 0;
		}		
	if(pieceType == (rook|BLACK_POS))				
		{
			if(m.from==0x70)
				BoardStatus.blackQ = 0;
			if(m.from==0x77)
				BoardStatus.blackK = 0;
		}

	if( board[m.to] ==  Q_ROOK_PP )		// if the rook is eated on this move
		BoardStatus.whiteQ = 0;			// sure it can't do a castle anymore
	if( board[m.to] ==  K_ROOK_PP )
		BoardStatus.whiteK = 0;
	if( board[m.to] == (Q_ROOK_PP | BLACK_POS))
		BoardStatus.blackQ = 0;
	if( board[m.to] == (K_ROOK_PP | BLACK_POS))
		BoardStatus.blackK = 0;
}


//------------------------------- unmakeMove------------------------------
// Unmakes a move passed as arg.
// assumes that the same move was previusly maked on the board.
// Castling rights are not restored in this function
void unMakeMove(MOVE m)
{
    Side = !Side;                               // switch sides backward

	if(m.status.Castle)							// in case of a king move must check for castling
		unMakeCastle(m);

	if(m.status.promotion)						// Check for promotion move
	{
		board[BSPT(m.to)]&=~PIECE_MASK;			// clean piece type
		board[BSPT(m.to)]|= pawn;				// depromote piece back to pawn
	}

	BSPP(m.to)= m.from;							// adjust the moving piece pointer
	board[m.from] =	board[m.to];				// Move the piece back	
	board[m.to] =	m.eat;						// and restor old piece in that square

	if( m.eat != empty )						// check move eaten a piece
			board[m.eat] = m.to;				// if so, restore eaten piece
}


//------------------------------ unMakeCastle ----------------------------
// Unmakes a Castle. Assumes that previus move what this castle
void unMakeCastle(MOVE m)
{
	int kingPos;
	kingPos =(m.status.Castle & CASTLE_COLOR)?0x74:0x04;

	if(m.status.Castle & CASTLE_K)
	{	// Make kingside Castling
		BSPP(kingPos+0x01)  = kingPos+0x03;				// adjust the moving piece pointer
		board[kingPos+0x03] = board[kingPos+0x01];		// Move the rook
		board[kingPos+0x01] = empty;					// and clear board corner
	}	
	else 	
	{	// Make queenside Castling
		BSPP(kingPos-0x01)  = kingPos-0x04;				// adjust the moving piece pointer
		board[kingPos-0x04] = board[kingPos-0x01];		// Move the rook
		board[kingPos-0x01] = empty;					// and clear board corner
	}		
}
