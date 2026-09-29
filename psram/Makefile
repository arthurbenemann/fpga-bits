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

include clock.mk

# Records the last clock plan built, so changing it (or PIPE) rebuilds.
clock.name: FORCE
	@echo $(VIDEO) $(CPU_HZ) $(PIPE) | cmp -s - $@ || echo $(VIDEO) $(CPU_HZ) $(PIPE) > $@

soc.json: soc.v video.v psram_spi.v psram_bus.v flash_spi.v $(RV)/uart_rx.v $(RV)/uart_fifo.v $(RV)/emitter_uart.v $(RV)/riscv.v $(RV)/pipe.v assemble.hexdump clock.name
	yosys -ql soc.yslog -p 'read_verilog -I$(RV) $(YDEFS) soc.v; synth_ice40 -dsp -top PSRAM_SOC -json $@'

soc.asc: soc.json icebreaker.pcf
	nextpnr-ice40 -ql soc.nplog --up5k --package sg48 --freq $(CPU_FREQ) --asc $@ --pcf icebreaker.pcf --json $<

soc.bin: soc.asc
	icepack $< $@

soc-prog: soc.bin
	iceprog $<

# boot_entry.h: the address of entry.s's `entry` label, boot.c's fixed
# hand-off point for the menu (see entry.s, menu.c). Generated after linking
# fw.elf rather than hardcoded, since it depends on the linker's layout.
assemble.hexdump boot_entry.h &: boot.c entry.s $(RV)/start.s $(RV)/putchar.s $(RV)/print.c $(RV)/bram.ld
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/start.s -o start.o
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax entry.s -o entry.o
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $(RV)/putchar.s -o putchar.o
	riscv64-unknown-elf-gcc $(CFLAGS) -ffunction-sections -fdata-sections -c $(RV)/print.c -o print.o
	riscv64-unknown-elf-gcc $(CFLAGS) -ffunction-sections -fdata-sections -c boot.c -o boot.o
	riscv64-unknown-elf-ld -T $(RV)/bram.ld -m elf32lriscv -nostdlib --no-relax --gc-sections start.o entry.o print.o putchar.o boot.o $(LIBGCC) -o fw.elf
	riscv64-unknown-elf-objcopy -O binary fw.elf fw.bin
	hexdump --no-squeezing -e '"%08x\n"' fw.bin > assemble.hexdump
	riscv64-unknown-elf-nm fw.elf | awk '$$2=="T" && $$3=="entry" {print "#define BOOT_ENTRY 0x" $$1}' > boot_entry.h

build/menu.o: boot_entry.h

# Programs that run from PSRAM, uploaded by the bootloader:
#   make load IMG=mandel.img | memtest.img | coremark.img | pi.img | chess.img
#   make bundle: all of them at once (menu.img first), picked from the menu
# MARCH: rv32i_zmmul, rv32im (CPU built with DIV=1) or rv32i.
MARCH    := rv32i_zmmul
MULTI    := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-multi-directory)
PICOLIBC := /usr/lib/picolibc/riscv64-unknown-elf/lib/$(MULTI)
PLIBGCC  := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-libgcc-file-name)
PFLAGS   := $(subst -march=rv32i ,-march=$(MARCH) ,$(CFLAGS)) -include $(CURDIR)/cpuhz.h
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

coremark.img: crt_psram.o $(CM_OBJ) build/fbcon.o psram.ld march.name
	riscv64-unknown-elf-ld -T psram.ld -m elf32lriscv -nostdlib --no-relax crt_psram.o $(CM_OBJ) build/fbcon.o \
		--start-group $(PICOLIBC)/libc.a $(PICOLIBC)/libm.a $(PLIBGCC) --end-group -o coremark.elf
	riscv64-unknown-elf-objcopy -O binary coremark.elf $@

# Plain programs: one .c here or in ../riscv, plus ../riscv's printf and fbcon.o
# (the console + the putchar() that feeds it and the UART; see fbcon.h).
RT_OBJ := crt_psram.o build/print.o build/fbcon.o

build/%.o: %.c march.name clock.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(PFLAGS) -c $< -o $@

build/%.o: $(RV)/%.c march.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(PFLAGS) -c $< -o $@

%.img: build/%.o $(RT_OBJ) psram.ld
	riscv64-unknown-elf-ld -T psram.ld -m elf32lriscv -nostdlib --no-relax $(RT_OBJ) $< $(PLIBGCC) -o $*.elf
	riscv64-unknown-elf-objcopy -O binary $*.elf $@

# picChess (psram/chess/): the engine (chess/*.c) plus the ORIGINAL picChess
# GUI (chess/gui/: chessVideo.c/chessInterface.c/h/chessSet.h and
# chessGame.c's state machine, from before the project's 2014 refactor) on
# top of a shim (chess/vga/) standing in for the dsPIC VGA/keyboard/serial/
# clock/audio libraries it originally called. No RT_OBJ here -- this
# doesn't use ../riscv's printf or the fbcon text console at all, it draws
# straight into the framebuffer itself (see chess/vga/VGA.c). Needs
# picolibc's libc.a for chessMoveGen.c's qsort and chessInterface.c's
# ctype.h/string.h calls (like coremark.img).
CHESS     := chess
CHESS_SRC := $(wildcard $(CHESS)/*.c) $(wildcard $(CHESS)/gui/*.c) $(wildcard $(CHESS)/vga/*.c)
CHESS_OBJ := $(addprefix build/chess_,$(notdir $(CHESS_SRC:.c=.o)))
CHESS_INC   := -I$(CHESS) -I$(CHESS)/gui -I$(CHESS)/vga
CHESS_FLAGS := $(PFLAGS) -fsigned-char $(CHESS_INC)
# picolibc's signed-char ctype table (_ctype_b) isn't in libc.a; this file only needs ctype.
build/chess_chessInterface.o: CHESS_FLAGS := $(PFLAGS) $(CHESS_INC)

vpath %.c $(CHESS):$(CHESS)/gui:$(CHESS)/vga

build/chess_%.o: %.c $(wildcard $(CHESS)/*.h $(CHESS)/gui/*.h $(CHESS)/vga/*.h) march.name clock.name
	@mkdir -p build
	riscv64-unknown-elf-gcc $(CHESS_FLAGS) -c $< -o $@

chess.img: crt_psram.o $(CHESS_OBJ) build/fbcon.o psram.ld march.name
	riscv64-unknown-elf-ld -T psram.ld -m elf32lriscv -nostdlib --no-relax crt_psram.o $(CHESS_OBJ) build/fbcon.o \
		--start-group $(PICOLIBC)/libc.a $(PLIBGCC) --end-group -o chess.elf
	riscv64-unknown-elf-objcopy -O binary chess.elf $@
	riscv64-unknown-elf-size -A chess.elf | head -4

# Host build of the same engine + GUI for quick off-board checking: VGA.c's
# swapV() dumps the monochrome board as ASCII art instead of blitting to a
# real framebuffer, and getkey.c reads stdin (see the #ifdef HOST in each).
# Not part of the board image.
chess/host: $(CHESS_SRC)
	cc -DHOST -O2 -Wall -I$(CHESS) -I$(CHESS)/gui -I$(CHESS)/vga -o $@ $(CHESS_SRC)

load: $(IMG)
	./load.py --baud $(BAUD) $(IMG)

BUNDLE := menu.img mandel.img coremark.img memtest.img pi.img chess.img
bundle: $(BUNDLE)
	./load.py --baud $(BAUD) --bundle $^

# Flash layout (see boot.c): bundle at 0x100000 (1 MB), Doom image at
# 0x200000 (doom/Makefile's flash target).
bundle.bin: $(BUNDLE)
	./load.py --bundle --out $@ $^

flash-bundle: bundle.bin
	iceprog -o 1M bundle.bin

$(PROJ).out: $(PROJ).v bench_iverilog.v
	iverilog -DBENCH -DSIM -DPASSTHROUGH_PLL -DBOARD_FREQ=10 -DCPU_FREQ=10 $^ -o $@


clean:
	rm -f $(PROJ).yslog $(PROJ).nplog $(PROJ).json $(PROJ).asc $(PROJ).rpt $(PROJ).bin
	rm -f $(PROJ)_tb $(PROJ)_tb.vcd $(PROJ)_syn.v $(PROJ)_syntb $(PROJ)_syntb.vcd
	rm -f $(PROJ).out
	rm -f soc.yslog soc.nplog soc.json soc.asc soc.bin clock.name
	rm -f start.o entry.o putchar.o print.o boot.o fw.elf fw.bin assemble.hexdump boot_entry.h
	rm -rf build crt_psram.o *.elf *.img march.name
	rm -f bundle.bin chess/host

.SECONDARY:
FORCE:
.PHONY: all prog clean sim soc soc-prog load bundle flash-bundle FORCE
