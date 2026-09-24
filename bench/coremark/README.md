# CoreMark on the simulator: what the cache should buy you

Measured on the RV32 simulator (`doom/iss/iss_cm.c`) running real CoreMark
(2K performance run, 10 iterations, `-O2`), linked entirely into PSRAM. The
CRCs match the reference (`crclist 0xe714`, `crcmatrix 0x1fd7`,
`crcstate 0x8e3a`), so the simulator executes it correctly.

```sh
./run.sh                 # rv32i, 4 KB, 16 B lines, 2-way, write-through, unified
./run.sh rv32im 8 16 2 1 # rv32im, 8 KB, write-back
```

## Per iteration

| | rv32i | rv32im |
|---|---:|---:|
| instructions | 760 K | **317 K** |
| loads | 55 K | 55 K |
| stores | 15 K | 15 K |
| code size | 16.0 KB | 14.6 KB |

The M extension cuts CoreMark's instruction count by **2.4×**. The matrix
kernel is multiply-heavy and each `mul` becomes a libgcc loop without it.

## Cache misses (unified, 16 B lines, write-through), 10 iterations

| cache | fetch misses | load misses | read miss rate |
|---|---:|---:|---:|
| 2 KB, 2-way | 17,314 | 9,417 | 0.33% |
| 4 KB, 1-way | 12,227 | 8,292 | 0.25% |
| **4 KB, 2-way** | **7,637** | **4,241** | **0.15%** |
| 8 KB, 2-way | 1,665 | 816 | 0.03% |

CoreMark's working set is small. Once any reasonable cache is in place, the
benchmark measures the core and not the memory system, so it is a poor
workload for tuning cache size or associativity.

## Projected iterations/s

Calibrated against the measured **0.4 it/s uncached**. The core timing model
is the multi-cycle FSM: 4 cycles per instruction, 6 per load, 5 per store. A
16-byte line fill on single-SPI is taken as 2.5× an uncached word.

| core clock (assumed) | uncached (measured) | cache, WT, no store buffer | cache, WT + 1-entry buffer | ceiling (all hits) | + M extension |
|---|---:|---:|---:|---:|---:|
| 12 MHz | 0.4 | 3.2 | 3.7 | 3.8 | 8.2 |
| 25 MHz | 0.4 | 5.6 | 7.4 | 7.9 | 16.0 |

- **The cache should give 8–18×.** If you see far less, look for lines not
  being filled, a victim choice that always picks the same way, or every
  access still stalling.
- **The store buffer is worth 15–32%.** Without it, write-through stores
  stall for a full uncached write each time and dominate the remaining
  stalls.
- **After the cache, the core's CPI is the wall.** With the cache you land
  within 3–15% of the ceiling, and QSPI adds almost nothing for CoreMark.
- **Next lever: the M extension, about 2.2×.** After that, pipelining.
- The 25 MHz row is the one consistent with single-SPI at SCLK = core clock:
  the calibrated uncached access comes out at 71 cycles, about one 64-bit
  command/address/data transaction plus overhead.
