//------------------------------------------------
//		chessInterface.c
//	Arthur Benemann 
//						26/05/2011
//------------------------------------------------
//  
//	Description:
// All the interface gfrom the user to the chess engine
// is made trought here.
// This module commands the outputs to the video, sound
// and serial.
//
// The main function is getMove(), who mhandels the user
//	input of moves
//
//
// Clock can be adjusted by entering "sDDMMYYhhmmss",
// in the text input mode
// DD - Day, MM - Month, YY - Year
// hh - Hour,mm - Minute,ss - Seconds
//
//
//	Requiriments:
//	Timer 1 - for the blinking piece
//
//-------------------------------------------------

// Ported to the iCEBreaker RISC-V SoC: no dsPIC ("../Compiler.h" dropped),
// PS/2 keyboard input replaced by UART bytes (getkey.h; same getKey()
// signature PS2IC.h declared), Audio dropped (audio.h is a no-op stub) --
// see chess/vga/ for all of this program's platform glue.
#include <ctype.h> 				// for isalnum
#include <string.h> 			// for strlen
#include "chessEngine.h"		// chess game definitions
#include "chessInterface.h"		// interfacing functions
#include "getkey.h"				// UART key input (was PS2IC.h)
#include "keymap.h"				// keyboard mapping
#include "VGA.h"				// Video Buffer and graphics functions
#include "text.h"				// Video text
#include "UART2.h"				// Serial I/O
#include "clock.h"				// for plotClock -- no RTC, stub

#include "audio.h"				// Audio dropped -- no-op stub (was Audio.h + sounds.h)




//------------------------------ VARIABLES  ----------------------------------------
TCursor	Cursor ;				// Cursor
char InputStr[16]=">";			// Input string buffer



MOVE  moveList[MOVELIST_SIZE];	// Moves that are show on the screen
int endML,firstML;				// moveList is a circular buffer

//------------------------------ PRIVATE PROTOTYPES --------------------------------
void textInput(char c);
int validSelect(void);
int moveCursor(unsigned char c);
int isDirEnt(unsigned char c);
void redraw(void);
unsigned checkCastle(MOVE m);
unsigned checkPromo(MOVE m);
unsigned getPromo(void);

//--------------------------------- MACROS --------------------------------------
#define isEnter(P)	((P==ENTER)||(P==KP5))

//--------------------------------- FUNCTIONS --------------------------------------

//-------------------------- getMove ----------------------------------
// gets a move input from the user, only acepts the valid moves
// user can type the move, os select it with a cursor
// Clock adjustment is also made here by entering: "sDDMMYYhhmmss"
int getMove(MOVE *m, unsigned char key)
{
	// (was: T1CON/PR1/_T1IF -- dsPIC Timer1 setup for the blink rate. No
	// hardware timer to configure here; now_ticks() in VGA.c is a
	// free-running counter, always going, nothing to arm.)

	if(key)										// Try to get a KeyCode
	{
		Cursor.pos   &= 0x77;					// Reset the cursor
		switch(Cursor.State)					//===== Cursor State Machine ====
		{
			default:
			case SC_NONE:						//------- No input -------
				if(isDirEnt(key))				// Test if is a arrow or enter, and goto CURSOR mode if yes
					Cursor.State = SC_CURSOR;
				else if(!isalnum(key))			// If key isn't alphanumeric or an arrow
					break;						// then can exit the SM
				else												
					Cursor.State = SC_TEXT;		// else slide downto Text mode without lossing the key
					
			case SC_TEXT:						//------- Text input -------			
				if(key==ESC){						// An ESC press return to NONE mode
						Cursor.State = SC_NONE;	
						InputStr[0]  = '>';
						InputStr[1]  = 0x0;
						break;
					}
				else if(key==ENTER)
					{							// An Enter press , get move or clock adjust
						if((InputStr[1]=='s') &&// check if is a clock setup input
						   (strlen(InputStr)==14))
						{  						// try to set clock date and time
							Nop();
							setRTCC(&InputStr[2]);
							Cursor.State = SC_NONE;	
							InputStr[0]  = '>';
							InputStr[1]  = 0x0;
							break;
						}
						strToMove(&InputStr[1],m);
						if(testMove(*m))			// test if is a valid move
						{	// valid move
							InputStr[0]  = '>';
							InputStr[1]  = 0x0;
							Cursor.pos   &= 0x77;		// Reset the cursor
							Cursor.State = SC_NONE; 
							return	TRUE;
						}
						break;
					}
				textInput(key);					// Process text inputed
				break;
			case SC_SEL:						//------- Cursor and piece Selected
				if(key == ESC){					// An ESC press return to CURSOR mode
					Cursor.State = SC_CURSOR;	
					break;					
				}				
				else if(isEnter(key) && 			// if enter on selected piece, diselect(SC_CURSOR)					   
				   	(Cursor.pos==Cursor.PieceSel)){
					Cursor.State = SC_CURSOR;
					break;						
				}
				else if(isEnter(key)){			// else, could be a move 
					m->from = Cursor.PieceSel;	// save move in a variable
					m->to   = Cursor.pos;		// with castling status if nedeed
					if(board[Cursor.pos]!=empty)
						m->eat  = board[Cursor.pos];
					else
						m->eat  = empty;
					m->status.Castle = checkCastle(*m);
						m->status.promotion = checkPromo(*m);
						if(testMove(*m))				// test if is a valid move
						{	// valid move
							Cursor.pos   &= 0x77;		// Reset the cursor
							Cursor.State = SC_NONE; 
							return TRUE;				// Received valid move
						}
						break;
					}
					else if(isalnum(key)){			// If Alphanumeric char go to TEXT mode
						Cursor.State = SC_TEXT;
						break;
					}			
													// if none of the above was true than the rest of this
													// state equals SC_CURSOR, so slide down 				
			case SC_CURSOR:						//------- Cursor on screen
				if(moveCursor(key))				// if received and arrow move the cursor
					break;
				else if(isalnum(key)){			// If Alphanumeric char go to TEXT mode
					Cursor.State = SC_TEXT;
					break;
				}	
				else if(key == ESC){				// An ESC press return to NONE mode
					Cursor.State = SC_NONE;	
					break;
				}
				else if( isEnter(key))			// With ENTER or Keypad5 goto SEL mode and selects a piece,
						if(validSelect())		// but first must test if the selected piece is valid
						{
							Cursor.PieceSel = Cursor.pos;
							Cursor.State = SC_SEL;	
						}
				break;
			}// switch(Cursor.State)		
	}	
	return FALSE;
}

//------------------- getGameType --------------------
// Shows a Box queyring the user to select a game type
// It uses a key from the caller, and modify a variable
// if it has sussefuly selected a variable returs TRUE
int getGameType(int *type,unsigned char key)
{
	*type &= 0x3;

	switch(key)					// Try to Move the cursor, or select
	{
		case KP8:				// Move cursor up
			(*type)--;
			(*type) &= 0x3;
			break;
		case KP2:				// Move cursor down
			(*type)++;
			(*type) &= 0x3;
			break;
		case ENTER:				// Return the mode selected
		case KP5:
			 return TRUE;		// Return true if mode is selected
		default:				// ingnore other keys
			break;				
	}
	// plot gameType box
	cleanHScreen();				// Clean Video Buffer
	plotGameTypeBox(*type);		
	swapV();
	return FALSE;
}

//------------------- getGameLevel --------------------
// Shows a Box queyring the user to select a game Level
// It uses a key from the caller, and modify a variable
// if it has sussefuly selected a variable returs TRUE
int getGameLevel(char *level,unsigned char key)
{
	(*level) &= 0x3;

	switch(key)					// Try to Move the cursor, or select
	{
		case KP8:				// Move cursor up
			(*level)--;
			(*level)&= 0x3;
			break;
		case KP2:				// Move cursor down
			(*level)++;
			(*level) &= 0x3;
			break;
		case ENTER:				// Return the mode selected
		case KP5:
			(*level) += 3;			// minimum Level is 3
			 return TRUE;		// Return true if mode is selected
		default:				// ingnore other keys
			break;	
	}
	// plot gameType box
	cleanHScreen();				// Clean Video Buffer
	plotGameLevelBox(*level);
	swapV();		
	return FALSE;
}


//------------- publishMove -------------
//adds a move to the move list and 
// send it via serial
void publishMove(MOVE m)
{
	char buf[10];
	

	// add Move to the moves list
	moveList[endML].from      = m.from;	// add move to the list
	moveList[endML].to        = m.to;
	moveList[endML].eat       = m.eat;
	moveList[endML].status.st = m.status.st;

	endML=(endML+1) % MOVELIST_SIZE;	// advance last entry pointer
	if(endML == firstML)				// if overwrite, forget first entry
		firstML=(firstML+1) % MOVELIST_SIZE;

	// Play sound for the move
	moveToSound(m);

	// send move via serial
	moveToStr(m,buf);
	putsU2(buf);
}


//------------- publishLevel -------------
// Plays a Sound for the level selected
void publishLevel(int level)
{
	switch(level){
		case 3:
			playSound(S_PIECEOFCAKE);
			break;
		case 4:
			playSound(S_GETSOME);
			break;
		case 5:
			playSound(S_DAMN);
			break;
		case 6:
			playSound(S_HOLY);
			break;
		default:
			break;
	}
}

//------------- textInput --------------
// Process the input of a char on text mode
void textInput(char c)
{
	unsigned char len;
	len = strlen(InputStr);			// Current leng of input string
	
	if(c == BKSP){					// if input was backspace, delet last char
		if(len>1)					// do not delet line mark
			InputStr[len-1] = 0x0; 
		return;
	}
	if(isprint(c)){					// if input was a printable char, append to the
		if((len+1)<sizeof(InputStr)){// end of the input string
			InputStr[len]   = c;
			InputStr[len+1] = 0;	// keep it NUL-terminated (bugfix: the
									// original left this out, so leftover
									// bytes from a longer previous move
									// resurfaced after a shorter one)
		}
		return;
	}
	
}


//------------- redrawChess() -----------------
// Refresh the screen. Uses cursor variable
// to check if must paint the cursor,
// if there is a selected piece
void redrawChess(void)
{
	char cursorPos;
	cleanHScreen();					// Clean Video Buffer
	plotBoard();					// Paint the board 
	plotMoveList();					// Paint the moves list
	plotTime();						// paint the time	
	
	switch(Cursor.State){
		case	SC_SEL:				// if a piece is selected, make it blink
			if((now_ticks()%(SEL_RATE/2))>(SEL_RATE/4))	// was TMR1 (dsPIC Timer1)
				plotPiece(Cursor.PieceSel,0);
		case SC_CURSOR:				// If is on one of the cursor modes, show it
			plotCursor(Cursor.pos);
			break;
		
		case   SC_TEXT:				// Draw Input line on the bottom of the board
			putsV(InputStr,0,1);	// with blinking cursor
			cursorPos =(strlen(InputStr)<<3);
			if((now_ticks()%SEL_RATE)>(SEL_RATE/2))	// was TMR1 (dsPIC Timer1, free-running 0..PR1)
				putV('_',cursorPos,1);
			else
				putV(' ',cursorPos,1);
			
		case   SC_NONE:				// Ther is nothing but the board to be draw	
		default:;
	}
	
	swapV();						// Display new frame
}

//------------- announceCheckmate ---------------------
// Function is called when a checkmate is made
// Alert via serial and display in the video
void announceCheckmate(void)
{
	playSound(S_CHECKMATE);

	cleanHScreen();					// Clean Video Buffer
	plotBoard();					// Paint the board 
	plotMoveList();					// Paint the moves list

	putsU2("Checkmate");
	putsV("CHECKMATE",24,1);	

	swapV();						// Display new frame
}
//------------- announceStalemate ---------------------
// Function is called when a stalemate is made
// Alert via serial and display in the video
void announceStalemate(void)
{
//	playSound(S_STALEMATE);

	cleanHScreen();					// Clean Video Buffer
	plotBoard();					// Paint the board 
	plotMoveList();					// Paint the moves list

	putsU2("Stalemate");
	putsV("STALEMATE",24,1);	

	swapV();						// Display new frame
}

//------------- waitForEnter --------------------------
// Just wait for the user to press the enter key
void waitForEnter(void)
{
	while(!isEnter(getKey()));
}


//------------- validSelect --------------
// Check if it's valid to select the piece 
// in the struct Cursor, return true if yes
int validSelect(void)
{
	if((board[Cursor.pos]!=empty)&&		// is selecting a piece ?
	   (SideOfBS(Cursor.pos)==Side))	// The selected piece is on the right side?)
		return TRUE;
	else
		return FALSE;
}

//------------- checkPromo --------------
// Check if move is a pawn promotion,
// returns promotion status for the move
unsigned checkPromo(MOVE m)
{
	int lineMask,side;
	if((BSType(m.from)&PIECE_MASK)==pawn)			// Only pawns can get promoted
	{
		side = SideOfBS(m.from);					// save side that is moving
		lineMask =(side == Black)?0x00:0x70;		// Get final row for that pawn
		if((m.to&ROW_MASK)== lineMask) 				// if pawn is going to the last rown, it needs a promo.
		{
			return getPromo();						// gets promotion input
		}
	}
	return empty;									// No promotion done
}

//-------------- getPromo --------------
// Gets a Promotion input from the user
unsigned getPromo(void)
{
	const unsigned char promoPieces [] = 
			{queen,rook,bishop,knight};
	unsigned cursor = 0;

	while(1) 	// loop until user selects something
	{
		// plot promotion box
		plotPromoBox(cursor);		
		swapV();
		switch(getKey())	// Try to get a Key press
		{
			case KP8:		// Move cursor up
				cursor--;
				cursor &= 0x3;
				break;
			case KP2:		// Move cursor down
				cursor++;
				cursor &= 0x3;
				break;
			case ENTER:		// Return the piece selected
			case KP5:
				return promoPieces[cursor];
			default:		// ingnore other keys
				break;
		}		
	}
}




//------------ isdirectional -------------
// Check if arg. is a directional key or enter
int isDirEnt(unsigned char c)
{
	switch(c){					// Test if is a arrow or enter
		case KP9: case KP8: 
		case KP7: case KP6:
		case KP4: case KP3: 
		case KP2: case KP1: 
		case ENTER:		
			return TRUE;
		default:
			return FALSE;
	}
}


#define MS(_p, _m) { *(_p)++ = ((_m)&7)+'a';  *(_p)++ = ((_m)>>4)+'1'; }


//------------ moveCursor -----------------
// Try to move the cursor in the direction passed
// as argument, return true if successful
int moveCursor(unsigned char c)
{
	switch(c){
		case KP9:				// An arrow press moves the cursor
			Cursor.y++;
			Cursor.x++;
			break;
		case KP8:			
			Cursor.y++;
			break;
		case KP7:
			Cursor.y++;
			Cursor.x--;
			break;
		case KP6:
			Cursor.x++;
			break;
		case KP4:
			Cursor.x--;
			break;
		case KP3:
			Cursor.y--;
			Cursor.x++;
			break;
		case KP2:
			Cursor.y--;
			break;
		case KP1:
			Cursor.y--;
			Cursor.x--;
			break;
		default:			// if not moved return false
			return FALSE;		
	}	
	return TRUE;
}

//---------------- moveToStr ------------
// Convert a MOVE variable to a algebraic
// chess notation string. 
// sizeof(Buf) must be > 6.
void moveToStr(MOVE m,char* buf)
{
    *buf++ = (m.from&7) +'a';		// file
    *buf++ = (m.from>>4)+'1';		// row
	*buf++ = (m.to&7) +'a';			// file
    *buf++ = (m.to>>4)+'1';			// row

	switch(m.status.promotion){		// add "=X" promotion chars if needed
		case queen:
			*buf++ = '=';
			*buf++ = 'q';
			break;
		case rook:
			*buf++ = '=';
			*buf++ = 'r';
			break;
		case bishop:
			*buf++ = '=';
			*buf++ = 'b';
			break;
		case knight:
			*buf++ = '=';
			*buf++ = 'n';
			break;
	}

    *buf = 0;						// string end
}

//---------------- strToMove ------------
// Convert algebraic chess notation string
// to a move.
void strToMove(char *str,MOVE *m)
{
	m->from = str[0]-'a'+ (str[1]-'1')*16;
	m->to   = str[2]-'a'+ (str[3]-'1')*16;
	if(board[m->to]!=empty)
		m->eat  = board[m->to];
	else
		m->eat  = empty;
	m->status.Castle = checkCastle(*m);
	if(str[4]=='=')						// check if there is a promotion
		switch(str[5]){
			case 'q':
				m->status.promotion = queen;
				break;
			case 'r':
				m->status.promotion = rook;
				break;
			case 'b':
				m->status.promotion = bishop;
				break;
			case 'n':
				m->status.promotion = knight;
				break;
			default:
				m->status.promotion = 0;
				break;
		}
	else
		m->status.promotion = 0;
	
}


//---------------- moveToSound ------------
// Play the sound corresponding to a move
void playLetter(char c)
{/*
	while(isPlaying());	// wait end of current sound
	switch(c){
		case 'a':
			playSound(S_A);
			break;			
		case 'b':
			playSound(S_B);
			break;			
		case 'c':
			playSound(S_C);
			break;			
		case 'd':
			playSound(S_D);
			break;			
		case 'e':
			playSound(S_E);
			break;			
		case 'f':
			playSound(S_F);
			break;			
		case 'g':
			playSound(S_G);
			break;			
		case 'h':
			playSound(S_H);
			break;
		case 't':
			playSound(S_TO);
			break;			
		case '1':
			playSound(S_1);
			break;			
		case '2':
			playSound(S_2);
			break;			
		case '3':
			playSound(S_3);
			break;			
		case '4':
			playSound(S_4);
			break;			
		case '5':
			playSound(S_5);
			break;			
		case '6':
			playSound(S_6);
			break;			
		case '7':
			playSound(S_7);
			break;			
		case '8':
			playSound(S_8);
			break;			
		default:
			break;
	}*/
}
void moveToSound(MOVE m)
{
	playSound(S_TUC);
/*
    playLetter((m.from&7) +'a');		// file
    playLetter((m.from>>4)+'1');		// row
	playLetter('t');
    playLetter((m.to&7) +'a');			// file
    playLetter((m.to>>4)+'1');			// row
/
	switch(m.status.promotion){		// add "=X" promotion chars if needed
		case queen:
			*buf++ = '=';
			*buf++ = 'q';
			break;
		case rook:
			*buf++ = '=';
			*buf++ = 'r';
			break;
		case bishop:
			*buf++ = '=';
			*buf++ = 'b';
			break;
		case knight:
			*buf++ = '=';
			*buf++ = 'n';
			break;
	}*/
}




//------------------- errorOverflow ---------------
// in case of overflow send a message via serial
// and show a box on the screen
void errorOverflow(void)
{
	putsU2(" OVERFLOWWWWW");
	plotOverflowBox();
}
