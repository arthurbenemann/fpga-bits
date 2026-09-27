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

# RISC-V SoC with PSRAM mapped at 0x800000 (soc.v). BRAM holds the UART bootloader
# (boot.c); programs are uploaded into PSRAM with load.py. The CPU and firmware
# runtime come from ../riscv.
RV     = ../riscv
LIBGCC := $(shell riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -print-libgcc-file-name)
CFLAGS := -march=rv32i -mabi=ilp32 -O2 -fno-pic -fno-stack-protector -w -I/usr/lib/picolibc/riscv64-unknown-elf/include

soc: soc.bin

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

# Records the last clock plan built, so changing it rebuilds.
clock.name: FORCE
	@echo $(VIDEO) $(CPU_HZ) | cmp -s - $@ || echo $(VIDEO) $(CPU_HZ) > $@

soc.json: soc.v video.v psram_spi.v psram_bus.v $(RV)/uart_rx.v $(RV)/uart_fifo.v $(RV)/emitter_uart.v $(RV)/riscv.v assemble.hexdump clock.name
	yosys -ql soc.yslog -p 'read_verilog -I$(RV) $(YDEFS) soc.v; synth_ice40 -dsp -top PSRAM_SOC -json $@'

soc.asc: soc.json icebreaker.pcf
	nextpnr-ice40 -ql soc.nplog --up5k --package sg48 --freq $(CPU_FREQ) --asc $@ --pcf icebreaker.pcf --json $<

soc.bin: soc.asc
	icepack $< $@

soc-prog: soc.bin
	iceprog $<

assemble.hexdump: boot.c $(RV)/start.s $(RV)/putchar.s $(RV)/print.c $(RV)/bram.ld
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/start.s -o start.o
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/putchar.s -o putchar.o
	riscv64-unknown-elf-gcc $(CFLAGS) -ffunction-sections -fdata-sections -c $(RV)/print.c -o print.o
	riscv64-unknown-elf-gcc $(CFLAGS) -ffunction-sections -fdata-sections -c boot.c -o boot.o
	riscv64-unknown-elf-ld -T $(RV)/bram.ld -m elf32lriscv -nostdlib --no-relax --gc-sections start.o print.o putchar.o boot.o $(LIBGCC) -o fw.elf
	riscv64-unknown-elf-objcopy -O binary fw.elf fw.bin
	hexdump --no-squeezing -e '"%08x\n"' fw.bin > $@

# Programs that run from PSRAM, uploaded by the bootloader:
#   make load IMG=mandel.img | memtest.img | coremark.img | fbtest.img
#   make bundle: all of them at once, picked from the bootloader menu
# MARCH: rv32i_zmmul, rv32im (CPU built with DIV=1) or rv32i.
MARCH    := rv32i_zmmul
MULTI    := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-multi-directory)
PICOLIBC := /usr/lib/picolibc/riscv64-unknown-elf/lib/$(MULTI)
PLIBGCC  := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-libgcc-file-name)
PFLAGS   := $(subst -march=rv32i ,-march=$(MARCH) ,$(CFLAGS)) -DCPU_HZ=$(CPU_HZ)
IMG      := coremark.img
CM       := coremark
CM_SRC   := $(wildcard $(CM)/*.c)
CM_OBJ   := $(patsubst $(CM)/%.c,build/cm_%.o,$(CM_SRC))
CM_FLAGS := $(PFLAGS) -I$(CM) -DPERFORMANCE_RUN=1 -DITERATIONS=0 -DFLAGS_STR='"$(PFLAGS)"'

# Records the last MARCH built, so switching it rebuilds.
march.name: FORCE
	@echo $(MARCH) | cmp -s - $@ || echo $(MARCH) > $@

crt_psram.o: crt_psram.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $< -o $@

build/cm_%.o: $(CM)/%.c $(wildcard $(CM)/*.h) march.name clock.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(CM_FLAGS) -c $< -o $@

coremark.img: crt_psram.o $(CM_OBJ) psram.ld march.name
	riscv64-unknown-elf-ld -T psram.ld -m elf32lriscv -nostdlib --no-relax crt_psram.o $(CM_OBJ) \
		--start-group $(PICOLIBC)/libc.a $(PICOLIBC)/libm.a $(PLIBGCC) --end-group -o coremark.elf
	riscv64-unknown-elf-objcopy -O binary coremark.elf $@

# Plain programs: one .c here or in ../riscv, plus the ../riscv printf/putchar.
RT_OBJ := crt_psram.o build/print.o build/putchar.o

build/%.o: %.c march.name clock.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(PFLAGS) -c $< -o $@

build/%.o: $(RV)/%.c march.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(PFLAGS) -c $< -o $@

build/putchar.o: $(RV)/putchar.s
	@mkdir -p build
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $< -o $@

%.img: build/%.o $(RT_OBJ) psram.ld
	riscv64-unknown-elf-ld -T psram.ld -m elf32lriscv -nostdlib --no-relax $(RT_OBJ) $< $(PLIBGCC) -o $*.elf
	riscv64-unknown-elf-objcopy -O binary $*.elf $@

load: $(IMG)
	./load.py --baud $(BAUD) $(IMG)

BUNDLE := mandel.img memtest.img coremark.img fbtest.img
bundle: $(BUNDLE)
	./load.py --baud $(BAUD) --bundle $^

$(PROJ).out: $(PROJ).v bench_iverilog.v
	iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10 $^ -o $@


clean:
	rm -f $(PROJ).yslog $(PROJ).nplog $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin
	rm -f $(PROJ)_tb $(PROJ)_tb.vcd $(PROJ)_syn.v $(PROJ)_syntb $(PROJ)_syntb.vcd
	rm -f $(PROJ).out
	rm -f soc.yslog soc.nplog soc.json soc.asc soc.bin clock.name
	rm -f start.o putchar.o print.o boot.o fw.elf fw.bin assemble.hexdump
	rm -rf build crt_psram.o *.elf *.img march.name

.SECONDARY:
FORCE:
.PHONY: all prog clean sim soc soc-prog load bundle FORCE
