# Clock plan (see soc.v). VIDEO=1: DVI out, CPU 12.5625 MHz, UART 3.140625 Mbaud.
# VIDEO=0: no video, CPU clock CPU_MHZ (a multiple of 3), UART 3 Mbaud.
# The firmware's timebase uses CPU_HZ, nextpnr CPU_FREQ (MHz), load.py BAUD.
VIDEO   := 1
CPU_MHZ := 15
ifeq ($(VIDEO),1)
CPU_HZ  := 12562500
CPU_FREQ:= 12.5625
BAUD    := 3140625
YDEFS   := -DVIDEO
else
CPU_HZ  := $(CPU_MHZ)000000
CPU_FREQ:= $(CPU_MHZ)
BAUD    := 3000000
YDEFS   := -DCPU_MHZ=$(CPU_MHZ)
endif
