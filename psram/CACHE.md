# PSRAM cache: what configuration, and why

Measured, not assumed. `../doom/iss/iss_cache.c` is the RV32IM simulator with a
configurable set-associative write-back cache; it boots the real Doom binary
against a real WAD, runs into E1M1, and reports misses and dirty-line
writebacks per steady-state gameplay frame.

```sh
cc -O2 -o iss_cache iss_cache.c
./iss_cache doom-play.elf freedoom1.wad <frames> <D$KB> <lineB> <ways> <1=WB,0=WT>
```

Cost model used for "QPI clk/frame" (4 bits/clock, `0xEB` read, `0x02` write):

```
read fill  = 2 cmd + 6 addr + 6 dummy + 2*lineBytes + 8 CS-high
writeback  = 2 cmd + 6 addr +           2*lineBytes + 8 CS-high
```

Baseline: **519,732 PSRAM data accesses per frame** (367 K loads, 149 K stores).

---

## Recommendation

| parameter | choose | why |
|---|---|---|
| **line size** | **16 bytes** | 32 B costs **1.43× more time**. Measured. |
| **associativity** | **2-way** | 20% better than direct-mapped, far cheaper than 2× capacity |
| **write policy** | **write-back + write-allocate** | write-through is **1.86× worse** |
| **capacity** | 16–32 KB | knee of the curve; more keeps helping but slowly |

**But do the two placement fixes first — they beat every cache parameter
combined, and they're free.** See "The thing that actually matters" below.

---

## Line size — the surprising one

D$ 8 KB, 1-way, write-back:

| line | Dmiss | Dwb | bytes/frame | **QPI clk/frame** |
|---:|---:|---:|---:|---:|
| 4 B | 92,508 | 30,682 | 492,760 | 3,511,608 |
| **8 B** | 62,008 | 19,699 | 653,656 | **2,986,672** |
| **16 B** | 46,695 | 15,032 | 987,632 | **3,243,066** |
| 32 B | 40,842 | 14,185 | 1,760,864 | 4,647,212 |
| 64 B | 41,995 | 16,194 | 3,724,096 | 8,631,186 |
| 128 B | 51,184 | 24,539 | 9,692,544 | 20,903,760 |

**The optimum is 8–16 bytes, not the conventional 32.** Going 16→32 B cuts
misses by only 13% while doubling the bytes moved — a net 1.43× loss. At 64 B
and beyond misses actually *increase* (the cache holds fewer lines, so
conflicts rise).

The reason is Doom's renderer: `R_DrawColumn` writes **vertically**, one byte
per 320-byte scanline stride. A wide line fetches 32 bytes to use one. Doom's
data side has genuinely poor spatial locality, and the usual "wider lines
amortise the command overhead" reasoning inverts.

I picked 16 B over the marginally-better 8 B because 8 B doubles the tag array
for an 8% gain. At 16 B the tag RAM is already the second-biggest cost.

## Capacity

16 B lines, 1-way, write-back:

| size | Dmiss | Dwb | QPI clk/frame |
|---:|---:|---:|---:|
| 4 KB | 63,656 | 25,503 | 4,661,568 |
| 8 KB | 46,695 | 15,032 | 3,243,066 |
| 16 KB | 37,367 | 11,573 | 2,573,322 |
| 32 KB | 29,671 | 9,477 | 2,057,130 |
| 64 KB | 23,465 | 7,855 | 1,644,150 |

Roughly 1.25× per doubling, no cliff. Spend what you have spare, don't agonise.

## Associativity

8 KB, 16 B, write-back:

| ways | Dmiss | Dwb | QPI clk/frame | vs 1-way |
|---:|---:|---:|---:|---:|
| 1 | 46,695 | 15,032 | 3,243,066 | — |
| 2 | 38,735 | 12,526 | 2,692,938 | **1.20×** |
| 4 | 35,850 | 10,964 | 2,462,172 | 1.32× |

2-way buys about as much as doubling the capacity (1.26×) for a fraction of the
RAM. Take it. 4-way isn't worth the extra comparator and LRU state.

## Write policy — not optional

8 KB, 16 B:

| policy | Dmiss | Dwb | QPI clk/frame |
|---|---:|---:|---:|
| write-back + allocate | 46,695 | 15,032 | **3,243,066** |
| write-through, no allocate | 111,957 | 0 | 6,045,678 |

**1.86× worse.** Doom does 149 K stores/frame to PSRAM; write-through turns
each into its own transaction with full command + address + CS overhead. Write-
back collapses them into 15 K line evictions.

---

## The thing that actually matters

I histogrammed PSRAM accesses per 4 KB page for one frame. The top of the list:

```
0x41046000  ld=76358  st=28284   end of .bss - hot static tables
0x417ff000  ld=42621  st=38351   THE STACK  (top of PSRAM)
0x412bd000  ld=43568  st=0       a texture/flat lump in the zone heap
0x4104b000  ld=4096   st=4063  }
0x4104c000  ld=4096   st=4254  }  seven consecutive pages, ~1 access per
0x4104d000  ld=4096   st=4216  }  byte, read AND written - this is
0x4104e000  ld=4096   st=4177  }  screens[0], the 64 KB software
0x4104f000  ld=4096   st=4256  }  framebuffer
0x41050000  ld=4096   st=4067  }
0x41051000  ld=4096   st=4234  }
```

Two of those are in the wrong memory:

**1. The stack is in PSRAM — 81,000 accesses per frame (16% of all PSRAM
traffic).** `riscv.lds` sets `__stacktop` to the top of PSRAM. Actual stack
depth is a few KB. Move it into SPRAM and 16% of the traffic disappears, along
with the most-reused region competing for cache lines.

**2. `screens[0]` is a 64 KB buffer in PSRAM that gets written once and read
once per frame — ~128,000 accesses (25% of traffic) with zero reuse.** Doom
renders into it, then `I_FinishUpdate()` `memcpy`s all 64,000 bytes into the
framebuffer peripheral. That's the exact pattern a cache cannot help with, and
being 64 KB it streams through and evicts everything else — which is why
misses plateau around 40 K no matter how big you make the cache.

**Point `screens[0]` at the framebuffer SPRAM and render directly into it.**
`I_FinishUpdate()` becomes a no-op. That removes 25% of PSRAM traffic, removes
the `memcpy`'s 64 K peripheral stores, and unclogs the cache.

Together the two moves remove **~41% of PSRAM accesses per frame** and take the
worst cache-hostile object out of the picture — for a linker script edit and a
few lines in `i_video.c`. No cache parameter comes close.

(Leave `screens[1..3]` in PSRAM — status bar and wipe buffers, touched far
less often.)

---

## Fitting it on the UP5K

4 SPRAMs × 32 KB = 128 KB, and SPRAM is **single-port**.

| SPRAMs | contents |
|---|---|
| 0 + 1 (64 KB, 32-bit wide) | framebuffer **= `screens[0]`**, 64,000 B used |
| 2 + 3 (64 KB, 32-bit wide) | one array holding the **stack** at the top and **cache data** below |

Sharing SPRAM2+3 between stack and cache data sounds wrong, but it works on
your core: the multi-cycle FSM only ever has one memory operation in flight
(`WAIT_INSTR`, then `LOAD`/`WAIT_DATA` are separate states), and the cache fill
engine only runs while the CPU is stalled. A pipelined core later would want
these split.

Tag array for 32 KB / 16 B / 2-way over an 8 MB space: 2048 lines, 1024 sets,
9 tag bits + valid + dirty = 11 bits × 2048 ≈ 22.5 kbit ≈ **6 EBRs**. You have
~14 free after the boot ROM. Note 8 B lines would need ~12 EBRs for the same
capacity — the other reason to stop at 16.

The framebuffer SPRAM is also read by video scanout; at 320×8bpp that's ~80
32-bit reads per line out of ~800 pixel clocks, so give video priority and the
CPU still gets ~90% of the cycles (this is what `vid_framebuf.v` in the
reference design does).

---

## Caveats

- One frame of E1M1's opening view, `freedoom1.wad`. Instruction counts varied
  ~3% across steady-state frames; a heavy firefight would differ.
- LRU is modelled exactly; a real design would likely use a cheaper
  pseudo-LRU, costing a little.
- The cost model assumes back-to-back transactions with no bus arbitration
  against the video scanout or SD card.
- tCEM is not binding at these line sizes: 16 B is 54 QPI clocks ≈ 0.54 µs at
  100 MHz, comfortably inside the 8 µs refresh window. It only becomes a
  concern past ~256 B lines.
