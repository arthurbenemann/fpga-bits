// The CPU clock in Hz, read from the SoC: it is chosen by the bitstream (turbo or safe).
#ifndef CPU_HZ
#define CPU_HZ (*(volatile unsigned *)0x410000)
#endif
