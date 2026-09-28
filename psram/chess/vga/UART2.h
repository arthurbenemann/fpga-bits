// UART2.h -- trimmed to what chessInterface.c actually calls (publishMove/
// errorOverflow's putsU2). Same names as the original dsPIC serial library
// (Firmware/SERIAL/UART2.h) so chessInterface.c's #include line only needed
// its path adjusted, not its calls.
#ifndef UART2_H
#define UART2_H
void initU2(void);
void putU2(int c);
void putsU2(char *s);
char getU2(void);
#define lineU2 putU2('\r');putU2('\n')
#endif
