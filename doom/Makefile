# Doom (doom-ascii / doomgeneric) as a PSRAM image for ../psram/soc.v.
#   make WAD=/path/to/doom1.wad     -> doom.img (program + IWAD, 5 MB: ~17 s upload)
#   make load                       upload it (keys: wasd move, q/e strafe, f fire, space use)
#   make sim                        run doom.img in ../psram/rvsim
# The upstream source is cloned into build/ at a pinned commit (not vendored);
# SRC=<dir> uses another checkout. DOOM_ARGS adds command-line arguments, e.g.
# DOOM_ARGS='"-timedemo","demo1",'. BLOCKS (3..11) and LOWDETAIL set the view.
# Doom draws straight into the DVI framebuffer; TEXT=1 draws it on the UART
# instead, as a COLS x ROWS text grid (e.g. COLS=160 ROWS=50 for a small font),
# COLOR=1 tinting it with ANSI colours. VIDEO and CPU_MHZ must match the
# bitstream (../psram/clock.mk); VIDEO=0 implies TEXT=1.
DOOM_GIT  := https://github.com/wojciech-graj/doom-ascii
DOOM_REV  := ce9f7eeb14cf1099b2a03007f919086a3a8be1e2
SRC       ?= build/doom-ascii/src
WAD       ?= doom1.wad
WAD_ADDR  ?= 0x8C0000
STACK_TOP ?= 0x1800
COLS      ?= 80
ROWS      ?= 25
COLOR     ?= 0
DOOM_ARGS ?=
include ../psram/clock.mk
TEXT      ?= $(if $(filter 1,$(VIDEO)),0,1)
ifeq ($(TEXT),1)
BLOCKS    ?= 6
LOWDETAIL ?= 1
else
BLOCKS    ?= 10
LOWDETAIL ?= 0
endif

MARCH    := rv32i_zmmul
MULTI    := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-multi-directory)
PICOLIBC := /usr/lib/picolibc/riscv64-unknown-elf/lib/$(MULTI)
LIBGCC   := $(shell riscv64-unknown-elf-gcc -march=$(MARCH) -mabi=ilp32 -print-libgcc-file-name)
CFLAGS   := -march=$(MARCH) -mabi=ilp32 -O2 -fno-pic -fno-stack-protector -w -std=gnu99 \
            -ffunction-sections -fdata-sections -D_DEFAULT_SOURCE \
            -isystem /usr/lib/picolibc/riscv64-unknown-elf/include -I$(SRC)

UPSTREAM := dummy am_map doomdef doomstat dstrings d_event d_items d_iwad d_loop d_main d_mode \
	d_net f_finale f_wipe g_game hu_lib hu_stuff info i_cdmus i_endoom i_joystick i_scale \
	i_sound i_system i_timer memio m_argv m_bbox m_cheat m_config m_controls m_fixed m_menu \
	m_misc m_random p_ceilng p_doors p_enemy p_floor p_inter p_lights p_map p_maputl p_mobj \
	p_plats p_pspr p_saveg p_setup p_sight p_spec p_switch p_telept p_tick p_user r_bsp r_data \
	r_draw r_main r_plane r_segs r_sky r_things sha1 sounds statdump st_lib st_stuff s_sound \
	tables v_video wi_stuff w_checksum w_file w_main w_wad z_zone i_input i_video doomgeneric
OBJ := $(UPSTREAM:%=build/%.o) build/dg_uart.o

all: doom.img

build:
	mkdir -p build

$(SRC)/doomgeneric.h:
	git clone -q $(DOOM_GIT) build/doom-ascii
	git -C build/doom-ascii checkout -q $(DOOM_REV)

build/%.o: $(SRC)/%.c | $(SRC)/doomgeneric.h build
	riscv64-unknown-elf-gcc $(CFLAGS) -c $< -o $@

# dg_uart.c replaces these upstream functions.
build/m_misc.o build/i_system.o build/i_video.o: build/%.o: $(SRC)/%.c Makefile | $(SRC)/doomgeneric.h build
	riscv64-unknown-elf-gcc $(CFLAGS) -c $< -o $@
	riscv64-unknown-elf-objcopy --weaken-symbol=M_FileExists --weaken-symbol=I_ZoneBase \
		--weaken-symbol=I_InitGraphics --weaken-symbol=I_SetPalette --weaken-symbol=I_FinishUpdate --weaken-symbol=I_Error $@

# Records the view options, so changing them on the command line rebuilds dg_uart.o.
OPTS := $(DOOM_ARGS) $(BLOCKS) $(LOWDETAIL) $(CPU_HZ) $(TEXT) $(COLS) $(ROWS) $(COLOR)
build/opts: FORCE | build
	@echo '$(OPTS)' | cmp -s - $@ || echo '$(OPTS)' > $@

build/dg_uart.o: dg_uart.c Makefile build/opts | $(SRC)/doomgeneric.h build
	riscv64-unknown-elf-gcc $(CFLAGS) -DDOOM_ARGS='$(DOOM_ARGS)' -DBLOCKS=$(BLOCKS) -DLOWDETAIL=$(LOWDETAIL) -DCPU_HZ=$(CPU_HZ) -DTEXT=$(TEXT) -DCOLS=$(COLS) -DROWS=$(ROWS) -DCOLOR=$(COLOR) -c $< -o $@

build/crt_doom.o: crt_doom.s | $(SRC)/doomgeneric.h build
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -mno-relax $< -o $@

build/wad.o: wad.s $(WAD) | $(SRC)/doomgeneric.h build
	riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -c -x assembler-with-cpp -DWAD_FILE='"$(abspath $(WAD))"' $< -o $@

doom.elf: build/crt_doom.o $(OBJ) build/wad.o doom.ld
	riscv64-unknown-elf-ld -T doom.ld -m elf32lriscv -nostdlib --no-relax --gc-sections \
		--defsym WAD_ADDR=$(WAD_ADDR) --defsym _stack_top=$(STACK_TOP) -Map doom.map \
		build/crt_doom.o $(OBJ) build/wad.o \
		--start-group $(PICOLIBC)/libc.a $(PICOLIBC)/libm.a $(LIBGCC) --end-group -o $@
	riscv64-unknown-elf-size -A $@ | head -4

doom.img: doom.elf
	riscv64-unknown-elf-objcopy -O binary $< $@

load: doom.img
	../psram/load.py --baud $(BAUD) $<

../psram/rvsim: ../psram/rvsim.c
	$(MAKE) -C ../psram rvsim

sim: doom.img ../psram/rvsim
	../psram/rvsim doom.img -p 0x$$(riscv64-unknown-elf-nm doom.elf | grep -w I_FinishUpdate | cut -d' ' -f1)

clean:
	rm -rf build/*.o doom.elf doom.img doom.map

.PHONY: all clean sim load

FORCE:
.PHONY: FORCE
