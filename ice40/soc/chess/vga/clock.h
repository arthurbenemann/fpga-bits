// clock.h -- stub for the dsPIC RTC library (Firmware/CLOCK/clock.h). No RTC
// on this board, so getTime() just reports nothing (plotTime() then draws
// an empty string, i.e. no time is shown) and setRTCC() is a no-op --
// chessInterface.c's clock-adjust-by-typing-"sDDMMYYhhmmss" feature quietly
// does nothing rather than being ripped out of getMove()'s state machine.
#ifndef CLOCK_H
#define CLOCK_H
void getTime(char *str);
void setRTCC(char *str);

// getMove()'s clock-set path calls the dsPIC compiler's Nop() intrinsic
// (a literal no-op instruction) right before setRTCC(); harmless either
// way since setRTCC() itself is a no-op here too.
#define Nop() ((void)0)
#endif
