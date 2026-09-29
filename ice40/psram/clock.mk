# Clock plan (see soc.v). VIDEO=1: DVI out, CPU 25.125 MHz (= pixel clock), UART 3.140625 Mbaud.
# VIDEO=0: no video, CPU clock CPU_MHZ (a multiple of 3), UART 3 Mbaud.
# PIPE=1: the pipelined core (../riscv/pipe.v) instead of Processor.
# The firmware's timebase uses CPU_HZ, nextpnr CPU_FREQ (MHz), load.py BAUD.
VIDEO   := 1
CPU_MHZ := 15
PIPE    := 1
# SLOW=1: VIDEO build with the CPU at half speed (12.5625 MHz), in spec: the safe fallback
# if a turbo build's placement turns out flaky.
SLOW    := 0
ifeq ($(VIDEO),1)
BAUD    := 3140625
YDEFS   := -DVIDEO
ifeq ($(SLOW),1)
CPU_HZ  := 12562500
CPU_FREQ:= 12.5625
YDEFS   += -DSLOW
else
CPU_HZ  := 25125000
CPU_FREQ:= 25.125
endif
else
CPU_HZ  := $(CPU_MHZ)000000
CPU_FREQ:= $(CPU_MHZ)
BAUD    := 3000000
YDEFS   := -DCPU_MHZ=$(CPU_MHZ)
endif
ifeq ($(PIPE),1)
YDEFS   += -DPIPE
endif
