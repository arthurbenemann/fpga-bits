# Minimal viable bare-metal Doom

All figures below are **measured** — I built `smunaut/doom_riscv` for RV32
(gcc 13.2, `-O2 -flto`) and read the sizes off the ELF. Build recipe at the
bottom; it works.

## Yes, you can just compile it

`smunaut/doom_riscv` builds for bare-metal RV32 essentially out of the box.
The only work was glue for picolibc (the port was written against newlib) —
about 25 lines, in `picolibc_glue.c` next to this file.

**But compiling is the easy half.** The binary targets a specific SoC memory
map (`src/riscv/config.h`), and that SoC is the project:

```c
#define VID_BASE    0x81000000   /* framebuffer as a peripheral */
#define UART_BASE   0x82000000
#define LED_BASE    0x83000000
/* riscv.lds */
ROM   0x40100000  1024k          /* code, XIP from memory-mapped flash */
PSRAM 0x41000000  8192k          /* data + bss + 6 MB zone heap        */
```

## The memory budget (measured)

| what | size | lives in |
|---|---:|---|
| `.text` | 181,104 B | flash |
| `.rodata` | 49,212 B | flash |
| **code + rodata** | **225 KB** | **flash, executed in place** |
| `.data` | 86,452 B | RAM |
| `.bss` | 205,536 B | RAM |
| stack | 4,096 B | RAM |
| **static RAM** | **289 KB** | **PSRAM** |
| zone heap (`I_ZoneBase`) | **6 MB** | PSRAM |
| **total RAM** | **≈ 6.3 MB** | **fits 8 MB with 1.7 MB spare** |
| WAD | 4.0 MB (shareware) | **flash — 0 bytes of RAM** |
| framebuffer | 64 KB | **video SPRAM — 0 bytes of main RAM** |

Three things never touch main memory, and that is the whole trick:

- **The WAD is read in place from memory-mapped flash.** `libc_backend.c` has a
  three-line "filesystem": `{ "doomu.wad", 12408292, (void*)0x40200000 }`, and
  `open`/`read`/`lseek` just index into flash. Doom's `W_CacheLumpNum` pulls
  lumps through it on demand.
- **Code executes in place from flash** — 225 KB of it, in a 1 MB window.
- **The framebuffer is a peripheral**, not an array.

### Why this matters for your board

**Do not plan on copying the WAD into PSRAM.** If you do:

```
6.3 MB (heap + static) + 4.0 MB (shareware WAD) = 10.3 MB  >  8 MB
```

One PMOD isn't enough. You'd have to cut the zone heap to ~3.5 MB, which is
right at Doom's edge. Keep the WAD in flash and one 8 MB board is comfortable —
**this is why the reference design works on exactly your memory size.** The
second PMOD and the SD card are not needed for Doom.

### Flash budget

iCEBreaker has 16 MB. Bitstream ~104 KB + code 225 KB + shareware WAD 4.0 MB
≈ **4.3 MB used**. Even Ultimate Doom (12.4 MB) fits, at ~13 MB.

## The M extension is not optional

Both builds link, and code size barely moves — but that hides the cost:

| | code+rodata | hardware `mul`/`div` | libgcc calls |
|---|---:|---:|---:|
| `rv32im` | 224.9 KB | **722** | 0 |
| `rv32i` | 233.6 KB | 0 | **303** |

303 call sites into `__mulsi3` / `__divsi3` / `__udivsi3` / `__umodsi3`, each a
function call plus a ~32-iteration loop, sitting in the renderer's inner loops.
The reference builds `-march=rv32im` for a reason.

From `RESOURCES.md`: a 32×32→64 multiplier costs **4 of your 8 DSP blocks and
48 LUTs**. Add it.

## So: the minimal SoC

Everything here is required; nothing else is.

1. **RV32IM core at ~20 MHz.** Yours is RV32I and P&Rs at 21.28 MHz, so the
   clock is fine — it needs the `M` extension (4 DSPs + 48 LUTs for `MUL`,
   plus a sequential divider) or a swap to picorv32/VexRiscv.
2. **Memory-mapped QSPI flash reader, cached.** Serves both code XIP and WAD
   reads. Arguably more important than the PSRAM controller — it carries the
   instruction stream.
3. **QSPI PSRAM controller, cached.** 6.3 MB of heap and static data.
4. **Output.** Either a framebuffer peripheral (64 KB = 2 SPRAMs, 320×200×8bpp)
   or, to skip video hardware entirely, ANSI over UART — that's a rewrite of
   `i_video.c`'s `I_FinishUpdate()` and nothing else.

Not needed: SD card, filesystem, second PMOD, MMU, interrupts, RTOS, Linux.

**The truly minimal build is RV32IM + cached flash + cached PSRAM + UART** —
no video hardware at all.

## Build recipe (verified)

```sh
git clone --depth 1 https://github.com/smunaut/doom_riscv
cd doom_riscv/src/riscv
# Debian/Ubuntu: apt install gcc-riscv64-unknown-elf
SRC=$(ls ../*.c | grep -vE '/(d_main|s_sound)\.c$' | tr '\n' ' ')
riscv64-unknown-elf-gcc -w -O2 -march=rv32im -mabi=ilp32 -ffreestanding -flto \
  -nostartfiles -fomit-frame-pointer -Wl,--gc-sections \
  --specs=picolibc.specs -D_DEFAULT_SOURCE -DNORMALUNIX -I.. \
  -Wl,-Bstatic,-T,riscv.lds,--strip-debug -o doom-riscv.elf \
  $SRC d_main.c i_main.c i_net.c i_sound.c i_system.c i_video.c s_sound.c \
  start.S console.c libc_backend.c mini-printf.c picolibc_glue.c
riscv64-unknown-elf-size doom-riscv.elf
```

Three gotchas, all of which cost me a build each:

- `-D_DEFAULT_SOURCE` — picolibc hides POSIX (`O_RDONLY`, `struct stat`)
  without it, and `w_wad.c` needs them.
- `-DNORMALUNIX` — `w_wad.c`'s includes are inside `#ifdef NORMALUNIX`. If you
  override `CFLAGS` on the make command line you lose the Makefile's `+=` and
  this silently disappears.
- `picolibc_glue.c` — picolibc wants unprefixed `open`/`read`/`lseek`/`close`/
  `fstat`/`stat` plus explicit `stdin`/`stdout`/`stderr`; the port supplies
  newlib-style `_`-prefixed ones. Don't `#include <fcntl.h>` globally to fix
  this: Doom has an enum constant named `open` in `p_spec.h`.

With the real toolchain (`riscv-none-embed-`, newlib) none of this applies and
plain `make` works.
