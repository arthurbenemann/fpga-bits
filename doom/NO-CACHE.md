# Can Doom run without caches?

**Yes — it will run, and it will be correct. It will also be about 1 frame per
second at the absolute best, and roughly 1 frame per 7 seconds on your current
controller. The cache that fixes this costs about 60 LUTs.**

Everything below is measured. I wrote an RV32IM simulator with doom_riscv's
exact memory map (`iss/iss.c`), booted the real Doom binary on it with a real
WAD, drove it into E1M1, and counted every instruction fetch and data access
per rendered frame. Then I added a direct-mapped cache model and swept sizes.

```sh
cc -O2 -o iss iss.c
./iss doom-play.elf freedoom1.wad <frames> [icache_lines] [dcache_lines]
```

## What one gameplay frame actually costs

Steady state, E1M1, 320×200, measured over frames 9–25:

| | per frame |
|---|---:|
| instructions | **1,869,493** |
| instruction fetches (all from flash) | **1,869,493** |
| data accesses to PSRAM | **516,760** |
| data accesses to flash (rodata) | 2,868 |
| framebuffer stores (peripheral) | ~64,000 |
| **total off-chip memory transactions** | **≈ 2,389,000** |

Note instruction fetch is **78%** of all memory traffic. Doom's renderer is
not memory-bound on data — it is bound on *fetching its own code*.

(The title screen is only ~733 K instructions/frame. Don't calibrate on it;
it's a static blit, not 3D rendering.)

## Uncached frame times

A single uncached 32-bit QPI read is 2 (cmd) + 6 (addr) + 6 (dummy) + 8 (data)
+ 8 (CS# high) = **30 QPI clocks**.

| memory | per access | frame time | fps |
|---|---:|---:|---:|
| QPI x4 @ 100 MHz | 300 ns | **0.72 s** | **1.4** |
| QPI x4 @ 50 MHz (realistic over a PMOD) | 600 ns | 1.43 s | 0.7 |
| **single-SPI @ 25 MHz — your controller today** | 2.88 µs | **6.9 s** | **0.15** |

For context, the CPU itself would take ~0.42 s/frame (1.87 M instructions at
~4.5 cycles each, 20 MHz). **Uncached, memory is bigger than the entire CPU
time** — the processor spends its life waiting.

## What a cache buys (measured miss counts)

Direct-mapped, 32-byte lines, same frame:

| I$ / D$ | I-misses | D-misses | total line fills | vs uncached |
|---|---:|---:|---:|---:|
| none | 1,869,493 | 519,628 | 2,389,121 | 1× |
| 4 KB / 4 KB | 28,394 | 64,021 | **92,415** | **26×** |
| 8 KB / 8 KB | 13,841 | 42,876 | 56,717 | 42× |
| 32 KB / 32 KB | 1,351 | 23,017 | 24,368 | **98×** |

A 32-byte line fill is 2+6+6+64+8 = 86 QPI clocks = 860 ns at 100 MHz.

| config | memory time/frame @100 MHz QPI | ceiling |
|---|---:|---:|
| uncached | 717 ms | 1.4 fps |
| 4 KB / 4 KB | 79 ms | 12.6 fps |
| 8 KB / 8 KB | 49 ms | 20.5 fps |
| 32 KB / 32 KB | 21 ms | 47.7 fps |

With any cache at all the bottleneck moves off memory and onto the CPU, which
is where you want it — at that point a better core buys you frames.

### If you only build one cache, build the instruction cache

Fetch is 78% of the traffic, so an I-cache alone does most of the work:

| config | frame time @100 MHz QPI | fps |
|---|---:|---:|
| nothing | 717 ms | 1.4 |
| **4 KB I-cache only** | **180 ms** | **5.5** |
| 32 KB I-cache only | 157 ms | 6.4 |
| 8 KB I + 8 KB D | 49 ms | 20.5 |

A 4 KB I-cache and nothing else is a **4× speedup**.

## What a cache costs

Synthesised for real (yosys 0.69, UP5K), direct-mapped, 32-byte lines, data
array in SPRAM:

```
32 KB direct-mapped cache:  60 LUT4   106 DFF   3 EBR   2 SPRAM
```

60 LUTs out of 5280 — **about 1% of the FPGA**. (That's a read-only cache with
idealised timing, so treat it as a lower bound; a production one with write
handling and proper stalls is more likely 150–300 LUTs. Still ~5%.)

And the decisive point: **you need the QPI state machine either way.** Command
assembly, dummy cycles, CS framing, the tCEM guard — all of that exists in the
uncached design too. A cache is a tag array and a fill counter bolted on top of
machinery you already had to build. Skipping it saves you a few hundred LUTs
and maybe a day, and costs you 20–40× in speed.

## So

- **Without caches: it works.** Nothing breaks, nothing is incorrect. ~1 fps
  with a 100 MHz QPI controller, ~0.7 fps at a realistic 50 MHz over a PMOD.
- **On your current single-SPI controller: one frame every 7 seconds.**
- **With a 4 KB I-cache: ~4× better, for ~60–200 LUTs.**
- **With 8 KB I + 8 KB D: memory stops being the bottleneck entirely.**

If the goal is "Doom appears on screen and moves", uncached QPI gets you there
and is a legitimate milestone — you'd see roughly one frame per second, which
is enough to prove the whole stack works. If the goal is "playable", you need
a cache, and the cache is the cheapest part of this entire project.

Terminal/ASCII output changes none of this: the bottleneck is instruction
fetch, not the display.

## Caveats

- Profiled with `freedoom1.wad` (28 MB) rather than shareware `DOOM1.WAD`
  (4 MB), because that's what's freely downloadable. Lump sizes differ, so
  WAD-read traffic would differ — but in steady-state gameplay the level is
  already cached in the zone heap and WAD reads are **zero** per frame, so the
  numbers above are unaffected.
- The frame profiled is E1M1's opening view. Busier scenes cost more; the
  instruction count varied only ~3% across the frames measured, but a heavy
  firefight would be worse.
- Cache model is direct-mapped with no write-allocate policy modelled on the
  D-side, so D-misses are pessimistic for a write-back design and optimistic
  for write-through.
- `iss.c` ignores CSRs and treats `ECALL`/`EBREAK` as no-ops; it is a profiling
  tool, not a verification model.
