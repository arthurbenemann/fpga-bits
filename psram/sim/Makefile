# Verification for the PSRAM SPI controller.
#
#   make check    run every check
#   make margin   sweep the MISO round-trip budget (old scheme vs fixed)
#   make tcem     show where the 8us refresh wall lands
#   make tearing  show the UART latching rdata mid-transfer
#   make clean
#
# Needs only iverilog. psram_model.v is a behavioural ESP-PSRAM64H
# (single-SPI mode) that also flags tCEM / tCPH violations.

IV   := iverilog -g2012
DUT  := ../psram.v
BLD  := build

# The stock corescore_emitter_uart in psram.v leaves `data`/`o_ready`
# uninitialised and has no reset, so it stays X forever in simulation and
# never transmits. Patch it in for the SoC-level test (see REVIEW.md #5).
$(BLD)/psram_uartinit.v: $(DUT) | $(BLD)
	sed 's/   reg \[9:0\] \t    data;/   reg [9:0] data = 0; initial o_ready = 0;/' $< > $@

$(BLD):
	mkdir -p $(BLD)

.PHONY: check margin tcem tearing clean

check: margin tcem tearing

# --- MISO sampling margin -------------------------------------------------
# Round trip = FPGA clk->pin (5ns) + PSRAM tCO + pin->FPGA (3ns).
# Old scheme samples on the SCLK rising edge -> budget is ONE core clk (20ns).
# spi_master with SAMPLE_LATE=1 samples on the falling edge -> TWO core clks.
margin: | $(BLD)
	@echo "=== as-is SPI module (psram.v), sweeping PSRAM tCO ==="
	@for t in 6 8 10 12 13 16 20; do \
	  $(IV) -DBENCH -Ptb_spi.TCO=$$t -o $(BLD)/m.out $(DUT) psram_model.v tb_spi.v 2>/dev/null; \
	  printf "  tCO=%-3sns  " $$t; vvp -n $(BLD)/m.out 2>/dev/null | grep -o "transfers=.*"; \
	done
	@echo "=== spi_master.v, SAMPLE_LATE=1 (sample on SCLK falling edge) ==="
	@for t in 6 8 12 16 20 24 30 33; do \
	  $(IV) -Ptb_fixed.TCO=$$t -Ptb_fixed.LATE=1 -o $(BLD)/f.out spi_master.v psram_model.v tb_fixed.v 2>/dev/null; \
	  printf "  tCO=%-3sns  " $$t; vvp -n $(BLD)/f.out 2>/dev/null | grep -o "xfers=.*"; \
	done

# --- tCEM: how long may CE# stay low? -------------------------------------
tcem: | $(BLD)
	@echo "=== CE# low time vs burst length (tCEM max 8us) ==="
	@for w in 96 192 256 512; do \
	  $(IV) -Ptb_tcem.W=$$w -o $(BLD)/t.out spi_master.v psram_model.v tb_tcem.v 2>/dev/null; \
	  vvp -n $(BLD)/t.out 2>/dev/null | grep ">>"; \
	done

# --- rdata torn by the free-running UART streamer -------------------------
tearing: $(BLD)/psram_uartinit.v
	@echo "=== does RegisterToUART latch rdata mid-transfer? ==="
	@$(IV) -DBENCH -o $(BLD)/s.out $(BLD)/psram_uartinit.v psram_model.v tb_tearing.v 2>/dev/null
	@vvp -n $(BLD)/s.out 2>/dev/null | grep ">>"

clean:
	rm -rf $(BLD) *.vcd
