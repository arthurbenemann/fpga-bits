Working throught https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/TUTORIALS/FROM_BLINKER_TO_RISCV/README.md

## Hardware sanity check (Mandelbrot on RISC-V + iCEBreaker)

`riscv.v` + `mandel.c` is a RV32I softcore with a hardware Mandelbrot
accelerator, rendered as an ANSI-colored, zooming image over UART. 

### Toolchain (Ubuntu/apt)

```
sudo apt-get install -y yosys nextpnr-ice40 fpga-icestorm iverilog \
    gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf picolibc-riscv64-unknown-elf
sudo usermod -aG dialout $USER   # log out/in (or `newgrp dialout`) to take effect
```

### Build + flash

```
cd riscv
make compile   # builds firmware (assemble.hexdump), used by riscv.v via $readmemh
rm -f riscv.json riscv.asc riscv.bin riscv.rpt   # Makefile doesn't track hexdump as a dep of the bitstream
make           # synthesize + place&route + pack -> riscv.bin
iceprog riscv.bin
```

### View it

```
picocom -b 1000000 /dev/ttyUSB1
```