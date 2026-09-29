# fpga-bits

Small FPGA projects, by board family.

- [`ice40/`](ice40/): iCEBreaker (iCE40UP5K), Verilog with the open-source yosys/nextpnr flow. The main
  one is [`ice40/soc`](ice40/soc/): a RISC-V computer with PSRAM, HDMI output and a boot menu that
  runs Mandelbrot, CoreMark, pi, picChess and Doom.
- [`spartan/`](spartan/): older VHDL modules for the Papilio DUO (Spartan-6) + Logic Shield, built with
  Xilinx ISE.
