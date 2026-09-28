#!/usr/bin/env python3
"""Seed search for the turbo bitstream: synthesizes once, then runs nextpnr on new
seeds, JOBS at a time, until Enter or Ctrl-C, printing every result ranked by the
CPU clock's fmax. Results: out/seed_N.bin / .log.  ./seeds.py [first_seed] [jobs]"""
import glob, os, re, select, subprocess, sys, termios, tty

os.chdir(os.path.dirname(os.path.abspath(__file__)))
os.makedirs("out", exist_ok=True)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 100
jobs = int(sys.argv[2]) if len(sys.argv) > 2 else 4

if not os.path.exists("out/seed.json"):
    print("synthesizing...", flush=True)
    subprocess.run(["yosys", "-q", "-l", "out/seed.ys.log", "-p",
                    "read_verilog -I../riscv -DVIDEO -DPIPE soc.v; synth_ice40 -dsp -top PSRAM_SOC -json out/seed.json"],
                   check=True)

def fmax(log):
    m = re.findall(r"clock\s+'clk': ([\d.]+) MHz", open(log, errors="ignore").read())
    return float(m[-1]) if m else None

def table():
    rows = [(fmax(l), l) for l in glob.glob("out/*.log") if fmax(l)]
    print("\n  fmax   bitstream")
    for f, l in sorted(rows, reverse=True)[:15]:
        b = l[:-4] + ".bin"
        print(f"{f:6.2f}   {b if os.path.exists(b) else l}")
    print(flush=True)

def start(s):
    cmd = (f"nextpnr-ice40 -q -l out/seed_{s}.log --up5k --package sg48 --freq 25.125 "
           f"--asc out/seed_{s}.asc --pcf icebreaker.pcf --json out/seed.json --timing-allow-fail --seed {s} "
           f"&& icepack -s out/seed_{s}.asc out/seed_{s}.bin && rm out/seed_{s}.asc")
    return subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

running = {}
tty_ok = sys.stdin.isatty()
if tty_ok:
    saved = termios.tcgetattr(0)
    tty.setcbreak(0)
print("running; press any key or Ctrl-C to stop", flush=True)
try:
    while True:
        while len(running) < jobs:
            running[seed] = start(seed)
            seed += 1
        if tty_ok and select.select([0], [], [], 2)[0]:
            break
        if not tty_ok:
            select.select([], [], [], 2)
        for s, p in list(running.items()):
            if p.poll() is not None:
                del running[s]
                f = fmax(f"out/seed_{s}.log")
                print(f"seed {s}: {f} MHz", flush=True)
                table()
except KeyboardInterrupt:
    pass
finally:
    for p in running.values():
        p.kill()
    for s in running:
        for ext in (".log", ".asc"):
            try: os.remove(f"out/seed_{s}{ext}")
            except OSError: pass
    if tty_ok:
        termios.tcsetattr(0, termios.TCSADRAIN, saved)
    table()
    print("Try the best on the board: make multiboot.bin TURBO=out/seed_N.bin SAFE=out/slow_1.bin -B && iceprog multiboot.bin")
