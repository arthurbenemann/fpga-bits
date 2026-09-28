//------------------------------------------------
//		chessInterface.h
//	Arthur Benemann 
//						13/06/2011
//------------------------------------------------
//  
//	Description:
// Header for the functions used for the chess interface, video menus , etc.
//
//-------------------------------------------------

//------------------------------- STRUCTS ------------------------------
// GameTypes
enum gameType{PvP,PvC,CvP,CvC,};

// Cursor
typedef struct
{
	union
	{
		unsigned char pos;
		struct{
			unsigned x:3;
			unsigned :1;
			unsigned y:3;
		};	  
	};
	char PieceSel;
	enum{		
		SC_NONE,				// No input
		SC_CURSOR,				// Cursor on screen
		SC_SEL,					// Cursor and piece Selected
		SC_TEXT				// Text input
		} State; 	
} TCursor;

//----------------------------- CONSTANTS -------------------------------
#define SEL_RATE		0xffff		// Blinking rate for a selected piece
#define MOVELIST_SIZE 16			// Max. number of itens in the moves list
#define CURSOR_MASK	0x3FFC
#define BOARD_SIZE	128	 // Size of one side of the board, in pixels

//----------------------------- VARIABLES -------------------------------
extern TCursor	Cursor;					// Cursor

extern MOVE moveList[MOVELIST_SIZE];	// Moves that are show on the screen
extern int endML,firstML;				// moveList pointer

//----------------------------- FUNCTIONS ------------------------------
//--- Menus
int getGameType(int *type,unsigned char key);
int getGameLevel(char *level,unsigned char key);


//--- Plot Functions 
void redrawChess(void);			
void plotBoard(void);
void plotMoveList(void);
void plotAlgNotation(void);
void plotPromoBox(int cursorPos);
void plotGameTypeBox(int cursorPos);
void plotGameLevelBox(int cursorPos);
void plotOverflowBox(void);
void plotPiece(char pos,char piece);
void plotCursor(char pos);
void plotTime(void);
void plotChessSplash(void);
void errorOverflow(void);

//---- Move utilits
void moveToSound(MOVE m);	
void strToMove(char *str,MOVE *m);
void moveToStr(MOVE m,char* buf);
int getMove(MOVE *m, unsigned char key);

//---- Publishing Functions
void announceCheckmate(void);
void announceStalemate(void);
void publishMove(MOVE m);
void publishLevel(int level);

//---- aux. functions
void waitForEnter(void);

