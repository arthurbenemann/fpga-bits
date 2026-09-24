#!/bin/sh
# Build CoreMark for the RV32 simulator and run it through a cache model.
#   ./run.sh [arch=rv32i] [cacheKB=4] [lineB=16] [ways=2] [writeback=0] [unified=1]
# Needs: riscv64-unknown-elf-gcc, a host cc, git.
set -e
ARCH=${1:-rv32i}; KB=${2:-4}; LINE=${3:-16}; WAYS=${4:-2}; WB=${5:-0}; UNI=${6:-1}
HERE=$(cd "$(dirname "$0")" && pwd)
[ -d "$HERE/src" ] || git clone --depth 1 https://github.com/eembc/coremark.git "$HERE/src"
cc -O2 -o "$HERE/iss_cm" "$HERE/../../doom/iss/iss_cm.c"
cd "$HERE/src"
riscv64-unknown-elf-gcc -O2 -march=$ARCH -mabi=ilp32 -mno-relax -ffreestanding -nostdlib -nostartfiles \
  -I"$HERE" -I. -DHAS_FLOAT=0 -DITERATIONS=10 -DPERFORMANCE_RUN=1 -DFLAGS_STR="\"-O2 $ARCH\"" \
  -T "$HERE/link.ld" -o "$HERE/cm_$ARCH.elf" \
  "$HERE/crt0.S" "$HERE/core_portme.c" "$HERE/ee_printf.c" "$HERE/libmin.c" \
  core_list_join.c core_main.c core_matrix.c core_state.c core_util.c -lgcc
# args: elf, no-wad, frames(unused), D$ KB, line, ways, 1=write-back, 1=unified I+D
"$HERE/iss_cm" "$HERE/cm_$ARCH.elf" - 0 "$KB" "$LINE" "$WAYS" "$WB" "$UNI"
