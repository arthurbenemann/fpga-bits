//--------------------------------------------------------
//		chessGame.c
//	Arthur Benemann 03/05/2010
//--------------------------------------------------------
//
//	Description:
// 	State machine to play a chess game,
//  This routines control the chess game,
//	The routines are non-blocking, and must be called
//	periodicly
//
//--------------------------------------------------------
//------------------ INCLUDEs ----------------------------
#include "chessEngine.h"
#include "chessInterface.h"		// interfacing functions

//------------------------ Global Variables -----------------------------------
int type;
char deep;

enum {START,SPLASH,GET_TYPE, GET_LEVEL,PLAY,END} chessState = START;

//---------------------------- cheessInit -----------------------------------------
// Initialize the chess Game
void chessInit(void)
{
	// initialize the board
	initBoard();
	
	// Setup Game State machine
	chessState = SPLASH;
}

//----------------------------- chessGame -----------------------------------------
// Play an entire chess game
//	Return True When ended
int chessGame(unsigned char key)
{
	MOVE m; 

	switch(chessState){				 	// Chess game state Machine
		case START:
			initBoard();				// initialize the board
			chessState = SPLASH;
		case SPLASH:					// Display Splash Screen
			if(key!=0)	
				chessState = GET_TYPE;
			else
				plotChessSplash();
			return FALSE;

		case GET_TYPE:					// Shows a box to select the game type	
			if(getGameType(&type,key))	 		
			{
				if(type == PvP)			// If PVP no level select is needed
					chessState = PLAY;					
				else
					chessState = GET_LEVEL;	// gameType selected, advance game machine
			}
			return FALSE;

		case GET_LEVEL:
			if(getGameLevel(&deep,key))	// Shows a box to select the Deep of the search			
			{
				publishLevel(deep);
				chessState = PLAY;		// search deep selected, advance game machine
			}
			return FALSE;

		case PLAY:						// Play a move
			if( (type==CvC)                  ||
			   ((Side == White)&&(type==CvP))||
			   ((Side == Black)&&(type==PvC))  )
			{							// Computer move
				m = searchAlphaBeta(deep,INF_NEG,INF_POS);
			}
			else
			{							// Player move
				if(!getMove(&m,key))	// try to get a move
				{
					redrawChess();		// Repaint the screen with the new move	
					return FALSE;		
				}
			}

			makeMove(m);				// Make the move
			publishMove(m);				// and publish it
			redrawChess();				// Repaint the screen with the new move	


			// Test if game is not finished
			if(genMoves(Side)==0)		// check if there are no moves
			{							// in case of no moves it's a stalemate, or a checkmate
				moveStackPtr = moveStack;// and reset moveStack ( because of genMoves)
				if(kingIsInCheck(Side)) // if king is checked it's a checkmate
					announceCheckmate();
				else
					announceStalemate();
				chessState = END;
				return TRUE;			// Gameover
			}
			else
				moveStackPtr = moveStack;

			return FALSE;				// If not checkmateor stalemate game keeps running

		default:
		case END:
			return TRUE;					// Game is ended
	}	// Game state machine
}// chessGame
