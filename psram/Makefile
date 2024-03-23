PROJ = riscv

all: $(PROJ).rpt $(PROJ).bin

$(PROJ).json: $(PROJ).v
	yosys -ql $(PROJ).yslog -p 'synth_ice40 -top SOC -json $@' $<

$(PROJ).asc: $(PROJ).json icebreaker.pcf
	nextpnr-ice40 -ql $(PROJ).nplog --up5k --package sg48 --freq 10 --asc $@ --pcf icebreaker.pcf --json $<
#/usr/bin/nextpnr-ice40

$(PROJ).bin: $(PROJ).asc
	icepack $< $@

$(PROJ).rpt: $(PROJ).asc
	icetime -d up5k -c 10 -mtr $@ $<

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

sim: $(PROJ).out $(PROJ)_bench.v
	vvp -n $<
	

assemble:  #hacky, needs to be cleanned up
	riscv64-unknown-elf-gcc -O -march=rv32i -mabi=ilp32 assemble.s -o assemble.o -nostartfiles
	riscv64-unknown-elf-objcopy -O binary assemble.o assemble.bin
	hexdump -e '"%08x\n"' assemble.bin > assemble.hexdump


compile:
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -fno-pic -fno-stack-protector -w -Wl,--no-relax -c mandel.c 
	riscv64-unknown-elf-ld -T bram.ld -m elf32lriscv -nostdlib -norelax print.o putchar.o mandel.o /opt/fomu-toolchain-Linux/lib/gcc/riscv64-unknown-elf/8.3.0/rv32i/ilp32/libgcc.a -o b.bram.elf
	riscv64-unknown-elf-objcopy -O binary b.bram.elf b.bin
	hexdump --no-squeezing -e '"%08x\n"' b.bin > assemble.hexdump

$(PROJ).out: $(PROJ).v $(PROJ)_bench.v
	iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10 $^ -o $@


clean:
	rm -f $(PROJ).yslog $(PROJ).nplog $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin
	rm -f $(PROJ)_tb $(PROJ)_tb.vcd $(PROJ)_syn.v $(PROJ)_syntb $(PROJ)_syntb.vcd
	rm -f $(PROJ).out

.SECONDARY:
.PHONY: all prog clean sim assemble compile

