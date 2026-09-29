# TDC

Time-to-digital converter test: a signal is sampled along a carry-chain delay line, giving about
0.25 ns per tap. `decode.py` reads the samples over the UART (1 Mbaud) and plots hit histograms
(`icebreaker_tdc*.png`). `make` builds, `make prog` flashes.
