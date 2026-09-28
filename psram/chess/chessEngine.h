//------------------------------------------------
//		chessEngine.h
//	Arthur Benemann 
//						04/05/2011
//------------------------------------------------
//  
//	Description:
// Definitions for the chess game, and publishing
// of game functions
//
//-------------------------------------------------

#ifndef TRUE
	#define TRUE 1
#endif
#ifndef FALSE
	#define FALSE 0
#endif

//------------------------------- STRUCTS ------------------------------
// Piece codes
enum pieceCode{
    empty = 0, pawn = 1, knight	= 2, king = 3,
    bishop 	= 5, rook = 6, queen = 7
};

// Boast State
typedef struct{
	union{
		struct{
			unsigned char :4;
			unsigned char promotion:4;
			};			
		union{
			unsigned char Castle:4;
			struct{
				unsigned char whiteQ:1;
				unsigned char blackQ:1;
				unsigned char whiteK:1;
				unsigned char blackK:1;
				};	
			};
		unsigned char st;
		};
	} TBoardST;	


// Move variables
typedef struct {
	unsigned char from;		// Board square, move starting point
	unsigned char to;		// Board square, move ending point
	unsigned char eat;		// Piece Pointer, piece pointer of the eaten piece
	TBoardST	status;
	} MOVE ;



//----------------------------- CONSTANTS -------------------------------
//--- Castle
#define CASTLE_WQ		0x01		// Mask for White queenside castle rights
#define CASTLE_BQ		0x02		// Mask for Black queenside castle rights
#define CASTLE_Q		0x03        // Mask for queenside castle rights
#define CASTLE_WK		0x04		// Mask for White kingside castle 
#define CASTLE_BK		0x08		// Mask for Black kingside castle 
#define CASTLE_K		0x0C		// Mask for kingside castle 
#define CASTLE_COLOR	0x0A		// Mask for castle color black
#define CASTLE_COLOR_W	0x05		// Mask for castle color white
#define CASTLE_NONE		0x00
#define CASTLE_ALL		0x0F		// Full castle rights


//--- Game Score
#define INF_NEG   (-32767)
#define INF_POS   (-INF_NEG)
#define DRAW_SCORE 		-20000
#define WIN_SCORE 		INF_POS
#define LOSE_SCORE 		INF_NEG

//--- Side
#define White	0
#define Black	1

//--- Position
#define BLACK_POS	0x40
#define DELTA_TYPE		0x20
#define DELTA_POINTER	0x08
#define KING_POS		0x04
#define BKING_POS		0x74
#define Q_ROOK_PP		0x08
#define K_ROOK_PP		0x0F
#define PIECE_MASK		0x07
#define PP_EMPTY		-1
#define ROW_MASK		0x70
#define COL_MASK		0x07

//--- MoveStack
#define MAX_STACK	300 // maximum number of moves searched



//----------------------------- VARIABLES -------------------------------
//--- Board State
extern char 	board[128];
extern char 	Side;
extern  		TBoardST BoardStatus;

//--- Move Stack
extern MOVE		moveStack[MAX_STACK];	// Moves stack
extern MOVE*	moveStackPtr;			// Last input in the move stack


//--- Tables
extern const char movesKnight[8];
extern const char movesKing[8];
extern const char movesRook[4];
extern const char movesBishop[4];
extern const char movesQueen[8];
extern const char startBoard[128];
extern const int  pieceValue[8];
extern const char genOrder[];

//-------------------------------- MACROS --------------------------------
// returns the piece pointer for a board square index
#define BSPP(P)	(board[(unsigned)board[P]])	

// returns the piece type index for a board square index
#define BSPT(P) ((unsigned)board[P]+DELTA_TYPE)	

// returns the side of a board square
#define SideOfBS(P) (board[P]>BLACK_POS)

//	returns true if the pos if off the 0x88 board
#define IsOffBoard(P)	(P&0x88)
//	returns true if the pos if on the 0x88 board
#define IsOnBoard(P)	(!(P&0x88))

// Compare two move structures for equality
#define CompareMoves(A,B)	(((A).from == (B).from)	&&\
							   ((A).to == (B).to)	&&\
                              ((A).eat == (B).eat)	&&\
                        ((A).status.st == (B).status.st))



//----------------------------- FUNCTIONS ------------------------------
//--- Aux. Functions
int BSType(int)	;  				// returns the piece type for a board square index

//--- Chess Game Functions (psram/chess/main.c drives the game loop directly)
void initBoard();

//--- Chess Tests
int testMove(MOVE m);
int testAttack(unsigned char pos,unsigned char color);
int kingIsInCheck(int side);
unsigned checkCastle(MOVE m);

//--- Move Make, Unmake, Push
void makeMove(MOVE m);
void unMakeMove(MOVE m);
void pushMove(MOVE *m);

//--- Move Generator
int genMoves(unsigned char side);
int genMovesOrdered(unsigned char side);

//--- Evaluation
int evaluateBoard(void);

//--- Search
extern int nodeCnt;
int AlphaBeta( int depth, int alpha, int beta );
MOVE searchAlphaBeta( int depth, int alpha, int beta );
MOVE searchNegaMax( int depth );
int negaMax( int depth );

