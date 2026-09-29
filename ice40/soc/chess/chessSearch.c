//------------------------------------------------
//		chessSearch.c
//	Arthur Benemann 
//						23/05/2011
//------------------------------------------------
//  
//	Description:
//  A best move search function, uses the generator and the evaluation function
//  Generetes moves and seach them on a search tree, find the best andreturn it.
//
//  For a normal search it must be called with:
//		 "searchAlphaBeta(dep-'0',INF_NEG,INF_POS)"
//
//-------------------------------------------------
// Ported to the iCEBreaker RISC-V SoC (psram/chess/): dropped time.h/clock()
// and the per-node printf trace (no libc time on this bare-metal target;
// psram/chess/main.c reports per-depth progress itself via IO_COUNTER).
#include "chessEngine.h"
//---------------------alphaBeta ------------------------
// Returns the best move for a board state using the alphabeta algorithm

int nodeCnt;

int AlphaBeta( int depth, int alpha, int beta ) 
{
	// test if is a leaf node
    if ( depth <= 0 ) 					
	{
		nodeCnt++;
		if(Side)
			return evaluateBoard();
		else
			return -evaluateBoard();
 	}
   
	MOVE *first,*last;
	int score;
	
	// add moves to stack
	first = moveStackPtr;		// save stack bottom in a pointer
	if( genMovesOrdered(Side)==0)		// fill stack, and check if there are moves
	{							// in case of no moves it's a stalemate, or a checkmate
		if(kingIsInCheck(Side))
			alpha = LOSE_SCORE;	// This side lose if its king is in check and is with no moves
		else
			alpha = DRAW_SCORE;	// Draw
	}
	last  = moveStackPtr;		// save last move  in a pointer

	// search all moves
	while((--last) >= first)
	{
		//make move
		int castleTemp = BoardStatus.Castle;
		makeMove(*last);					
	
       	score = -AlphaBeta( depth - 1, -beta,-alpha );

		// unmake move
		unMakeMove(*last);									
		BoardStatus.Castle = castleTemp;

        if (score >= beta)
		{
			moveStackPtr = first;
            return beta;
		}
        if( score > alpha )
            alpha = score;

    }

	// clear moves genereted in the stack for this node
	moveStackPtr = first;
	
    return alpha;
}

		


MOVE searchAlphaBeta( int depth, int alpha, int beta ) 
{

	int score;
	MOVE *first,*last,best;

	nodeCnt =0;

	// add moves to stack
	first = moveStackPtr;		// save stack bottom in a pointer
	if(genMovesOrdered(Side)==0)		// fill stack, and check if there are moves
	{							// in case of no moves it's a stalemate, or a checkmate
		if(kingIsInCheck(Side))
			alpha = WIN_SCORE;
		else
			alpha = DRAW_SCORE;			
	}
	else						// if there is a first move
		best = *first;			// In case it only can lose

	last  = moveStackPtr;		// save last move  in a pointer

	// search all moves
	while((--last) >= first)
	{
		//make move
		int castleTemp = BoardStatus.Castle;
		makeMove(*last);					
	
       	score = -AlphaBeta( depth - 1, -beta,-alpha );
		
		// unmake move
		unMakeMove(*last);									
		BoardStatus.Castle = castleTemp;


        if (score >= beta)
		{
			moveStackPtr = first;
            return *last;
		}
        if( score > alpha )
		{
            alpha = score;
			best = *last;
		}

    }

	// clear moves genereted in the stack for this node
	moveStackPtr = first;

    return best;
}


//##############################################################
/////////////////DEBUG////////////////////////////////////////////
int negaMax( int depth ) 
{
	// test if is a leaf node
    if ( depth == 0 ) 					
	{
		if(Side)
			return evaluateBoard();
		else
			return -evaluateBoard();
 	}
   
	int max = INF_NEG;
	int score;
	MOVE *first,*last;
	
	// add moves to stack
	first = moveStackPtr;		// save stack bottom in a pointer
	genMoves(Side);				// fill stack

	last  = moveStackPtr;		// save last move  in a pointer

	// search all moves
	while((--last) >= first)
	{
		//make move
		int castleTemp = BoardStatus.Castle;
		makeMove(*last);					
	
       	score = -negaMax( depth - 1 );

        if( score > max )
            max = score;
		
		// unmake move
		unMakeMove(*last);									
		BoardStatus.Castle = castleTemp;
    }

	// clear moves genereted in the stack for this node
	moveStackPtr = first;
	
    return max;
}


MOVE searchNegaMax( int depth ) 
{
	int max = INF_NEG;
	int score;
	MOVE *first,*last,best;
	
	// add moves to stack
	first = moveStackPtr;		// save stack bottom in a pointer
	if(genMoves(Side)==0)				// fill stack
	{

	}
	last  = moveStackPtr;		// save last move  in a pointer

	// search all moves
	while((--last) >= first)
	{
		//make move
		int castleTemp = BoardStatus.Castle;
		makeMove(*last);					
	
       	score = -negaMax( depth - 1 );
		
        if( score > max )
		{
            max = score;
			best = *last;
		}

	
		// unmake move
		unMakeMove(*last);									
		BoardStatus.Castle = castleTemp;				
    }

	// clear moves genereted in the stack for this node
	moveStackPtr = first;
	
    return best;
}

