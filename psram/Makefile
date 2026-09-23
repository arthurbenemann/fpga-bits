PROJ = psram

all: $(PROJ).rpt $(PROJ).bin

$(PROJ).json: $(PROJ).v
	yosys -ql $(PROJ).yslog -p 'synth_ice40 -top SOC -json $@' $<

$(PROJ).asc: $(PROJ).json icebreaker.pcf
	nextpnr-ice40 -ql $(PROJ).nplog --up5k --package sg48 --freq 50 --asc $@ --pcf icebreaker.pcf --json $<
#/usr/bin/nextpnr-ice40

$(PROJ).bin: $(PROJ).asc
	icepack $< $@

$(PROJ).rpt: $(PROJ).asc
	icetime -d up5k -c 50 -mtr $@ $<

$(PROJ)_tb: $(PROJ)_tb.v $(PROJ).v
	iverilog -o $@ $^

$(PROJ)_tb.vcd: $(PROJ)_tb
	vvp -N $< +vcd=$@

$(PROJ)_syn.v: $(PROJ).json
	yosys -p 'read_json $^; write_verilog $@'

$(PROJ)_syntb: $(PROJ)_tb.v $(PROJ)_syn.v
	iverilog -o $@ $^ `yosys-config --datdir/ice40/cells_sim.v`

$(PROJ)_syntb.vcd: $(PROJ)_syntb
	vvp -N $< +vcd=$@

prog: $(PROJ).bin
	iceprog -S $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog -S $<

sim: $(PROJ).out bench_iverilog.v
	vvp -n $<

# RISC-V SoC with PSRAM peripheral (soc.v), running memtest.c from BRAM.
# The CPU and firmware runtime come from ../riscv.
RV     = ../riscv
FW     = memtest
LIBGCC := $(shell riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -print-libgcc-file-name)
CFLAGS := -march=rv32i -mabi=ilp32 -O2 -fno-pic -fno-stack-protector -w -I/usr/lib/picolibc/riscv64-unknown-elf/include

soc: soc.bin

soc.json: soc.v psram_spi.v psram_bus.v $(RV)/riscv.v assemble.hexdump
	yosys -ql soc.yslog -p 'read_verilog -I$(RV) soc.v; synth_ice40 -top PSRAM_SOC -json $@'

soc.asc: soc.json icebreaker.pcf
	nextpnr-ice40 -ql soc.nplog --up5k --package sg48 --freq 12 --asc $@ --pcf icebreaker.pcf --json $<

soc.bin: soc.asc
	icepack $< $@

soc-prog: soc.bin
	iceprog $<

assemble.hexdump: $(FW).c $(RV)/start.s $(RV)/putchar.s $(RV)/print.c $(RV)/bram.ld
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/start.s -o start.o
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/putchar.s -o putchar.o
	riscv64-unknown-elf-gcc $(CFLAGS) -c $(RV)/print.c -o print.o
	riscv64-unknown-elf-gcc $(CFLAGS) -c $(FW).c -o $(FW).o
	riscv64-unknown-elf-ld -T $(RV)/bram.ld -m elf32lriscv -nostdlib --no-relax start.o print.o putchar.o $(FW).o $(LIBGCC) -o fw.elf
	riscv64-unknown-elf-objcopy -O binary fw.elf fw.bin
	hexdump --no-squeezing -e '"%08x\n"' fw.bin > $@

$(PROJ).out: $(PROJ).v bench_iverilog.v
	iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10 $^ -o $@


clean:
	rm -f $(PROJ).yslog $(PROJ).nplog $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin
	rm -f $(PROJ)_tb $(PROJ)_tb.vcd $(PROJ)_syn.v $(PROJ)_syntb $(PROJ)_syntb.vcd
	rm -f $(PROJ).out
	rm -f soc.yslog soc.nplog soc.json soc.asc soc.bin
	rm -f start.o putchar.o print.o $(FW).o fw.elf fw.bin assemble.hexdump

.SECONDARY:
.PHONY: all prog clean sim soc soc-prog

