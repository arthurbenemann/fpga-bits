// getkey.h -- replaces the PS/2 keyboard (Firmware/KEYBOARD/PS2IC.h): same
// getKey() signature (non-blocking, 0 when nothing is ready), bytes now
// come from the UART instead. See getkey.c.
#ifndef GETKEY_H
#define GETKEY_H
void initKBD(void);
unsigned char getKey(void);
#endif
