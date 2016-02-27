--------------------------------------------------------------------------------
-- Copyright (c) 1995-2013 Xilinx, Inc.  All rights reserved.
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor: Xilinx
-- \   \   \/     Version: P.20131013
--  \   \         Application: netgen
--  /   /         Filename: topModule_synthesis.vhd
-- /___/   /\     Timestamp: Fri Feb 26 15:16:56 2016
-- \   \  /  \ 
--  \___\/\___\
--             
-- Command	: -intstyle ise -ar Structure -tm topModule -w -dir netgen/synthesis -ofmt vhdl -sim topModule.ngc topModule_synthesis.vhd 
-- Device	: xc6slx9-2-tqg144
-- Input file	: topModule.ngc
-- Output file	: C:\Users\Arthur\Documents\GitHub\fpga-bits\fm_transmitter\netgen\synthesis\topModule_synthesis.vhd
-- # of Entities	: 1
-- Design Name	: topModule
-- Xilinx	: C:\Xilinx\14.7\ISE_DS\ISE\
--             
-- Purpose:    
--     This VHDL netlist is a verification model and uses simulation 
--     primitives which may not represent the true implementation of the 
--     device, however the netlist is functionally correct and should not 
--     be modified. This file cannot be synthesized and should only be used 
--     with supported simulation tools.
--             
-- Reference:  
--     Command Line Tools User Guide, Chapter 23
--     Synthesis and Simulation Design Guide, Chapter 6
--             
--------------------------------------------------------------------------------


-- synthesis translate_off
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

entity topModule is
  port (
    CLK : in STD_LOGIC := 'X'; 
    GPIO0 : out STD_LOGIC; 
    AUDIO1_RIGHT : out STD_LOGIC; 
    AUDIO1_LEFT : out STD_LOGIC 
  );
end topModule;

architecture Structure of topModule is
  component counter
    port (
      clk : in STD_LOGIC := 'X'; 
      q : out STD_LOGIC_VECTOR ( 27 downto 0 ) 
    );
  end component;
  component rom_memory
    port (
      clka : in STD_LOGIC := 'X'; 
      addra : in STD_LOGIC_VECTOR ( 15 downto 0 ); 
      douta : out STD_LOGIC_VECTOR ( 8 downto 0 ) 
    );
  end component;
  component phase_adder
    port (
      clk : in STD_LOGIC := 'X'; 
      a : in STD_LOGIC_VECTOR ( 31 downto 0 ); 
      b : in STD_LOGIC_VECTOR ( 31 downto 0 ); 
      s : out STD_LOGIC_VECTOR ( 31 downto 0 ) 
    );
  end component;
  signal clk_272 : STD_LOGIC; 
  signal clk_32 : STD_LOGIC; 
  signal GPIO0_OBUF_3 : STD_LOGIC; 
  signal N0 : STD_LOGIC; 
  signal N1 : STD_LOGIC; 
  signal clock_manager_clkfx : STD_LOGIC; 
  signal clock_manager_clk0 : STD_LOGIC; 
  signal clock_manager_clkin1 : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_bdd8 : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0 : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_4_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_5_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_6_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_7_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_8_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_9_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_12_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_13_Q : STD_LOGIC; 
  signal Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_15_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_4_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_5_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_6_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_7_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_8_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_9_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_10_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_11_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_12_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_13_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_15_Q : STD_LOGIC; 
  signal Inst_fm_modulator_ph_shift_2_Q : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLK2X180_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLK2X_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLK180_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLK270_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLKFX180_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLKDV_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_PSDONE_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_CLK90_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_LOCKED_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_7_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_6_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_5_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_4_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_3_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_2_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_1_UNCONNECTED : STD_LOGIC; 
  signal NLW_clock_manager_dcm_sp_inst_STATUS_0_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_11_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_10_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_9_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_8_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_7_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_6_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_5_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_4_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_3_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_2_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_1_UNCONNECTED : STD_LOGIC; 
  signal NLW_addr_counter1_q_0_UNCONNECTED : STD_LOGIC; 
  signal addr_counter : STD_LOGIC_VECTOR ( 27 downto 12 ); 
  signal douta : STD_LOGIC_VECTOR ( 8 downto 8 ); 
  signal Inst_audio_dac_8bit_sum : STD_LOGIC_VECTOR ( 9 downto 0 ); 
  signal audio_data_signed : STD_LOGIC_VECTOR ( 8 downto 0 ); 
  signal Inst_fm_modulator_ph_shift_data : STD_LOGIC_VECTOR ( 12 downto 4 ); 
  signal Inst_fm_modulator_sum : STD_LOGIC_VECTOR ( 30 downto 0 ); 
  signal Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy : STD_LOGIC_VECTOR ( 8 downto 0 ); 
  signal Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut : STD_LOGIC_VECTOR ( 8 downto 0 ); 
  signal Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT : STD_LOGIC_VECTOR ( 8 downto 0 ); 
  signal Inst_audio_dac_8bit_unsigned_data : STD_LOGIC_VECTOR ( 8 downto 8 ); 
begin
  XST_VCC : VCC
    port map (
      P => N0
    );
  XST_GND : GND
    port map (
      G => N1
    );
  clock_manager_clkout1_buf : BUFG
    port map (
      O => clk_272,
      I => clock_manager_clkfx
    );
  clock_manager_clkout2_buf : BUFG
    port map (
      O => clk_32,
      I => clock_manager_clk0
    );
  clock_manager_dcm_sp_inst : DCM_SP
    generic map(
      CLKDV_DIVIDE => 2.000000,
      CLKFX_DIVIDE => 1,
      CLKFX_MULTIPLY => 10,
      CLKIN_DIVIDE_BY_2 => FALSE,
      CLKIN_PERIOD => 31.250000,
      CLKOUT_PHASE_SHIFT => "NONE",
      CLK_FEEDBACK => "1X",
      DESKEW_ADJUST => "SYSTEM_SYNCHRONOUS",
      DFS_FREQUENCY_MODE => "LOW",
      DLL_FREQUENCY_MODE => "LOW",
      DSS_MODE => "NONE",
      DUTY_CYCLE_CORRECTION => TRUE,
      FACTORY_JF => X"0000",
      PHASE_SHIFT => 0,
      STARTUP_WAIT => FALSE
    )
    port map (
      CLK2X180 => NLW_clock_manager_dcm_sp_inst_CLK2X180_UNCONNECTED,
      PSCLK => N1,
      CLK2X => NLW_clock_manager_dcm_sp_inst_CLK2X_UNCONNECTED,
      CLKFX => clock_manager_clkfx,
      CLK180 => NLW_clock_manager_dcm_sp_inst_CLK180_UNCONNECTED,
      CLK270 => NLW_clock_manager_dcm_sp_inst_CLK270_UNCONNECTED,
      RST => N1,
      PSINCDEC => N1,
      CLKIN => clock_manager_clkin1,
      CLKFB => clk_32,
      PSEN => N1,
      CLK0 => clock_manager_clk0,
      CLKFX180 => NLW_clock_manager_dcm_sp_inst_CLKFX180_UNCONNECTED,
      CLKDV => NLW_clock_manager_dcm_sp_inst_CLKDV_UNCONNECTED,
      PSDONE => NLW_clock_manager_dcm_sp_inst_PSDONE_UNCONNECTED,
      CLK90 => NLW_clock_manager_dcm_sp_inst_CLK90_UNCONNECTED,
      LOCKED => NLW_clock_manager_dcm_sp_inst_LOCKED_UNCONNECTED,
      DSSEN => N1,
      STATUS(7) => NLW_clock_manager_dcm_sp_inst_STATUS_7_UNCONNECTED,
      STATUS(6) => NLW_clock_manager_dcm_sp_inst_STATUS_6_UNCONNECTED,
      STATUS(5) => NLW_clock_manager_dcm_sp_inst_STATUS_5_UNCONNECTED,
      STATUS(4) => NLW_clock_manager_dcm_sp_inst_STATUS_4_UNCONNECTED,
      STATUS(3) => NLW_clock_manager_dcm_sp_inst_STATUS_3_UNCONNECTED,
      STATUS(2) => NLW_clock_manager_dcm_sp_inst_STATUS_2_UNCONNECTED,
      STATUS(1) => NLW_clock_manager_dcm_sp_inst_STATUS_1_UNCONNECTED,
      STATUS(0) => NLW_clock_manager_dcm_sp_inst_STATUS_0_UNCONNECTED
    );
  clock_manager_clkin1_buf : IBUFG
    generic map(
      CAPACITANCE => "DONT_CARE",
      IBUF_DELAY_VALUE => "0",
      IBUF_LOW_PWR => TRUE,
      IOSTANDARD => "DEFAULT"
    )
    port map (
      I => CLK,
      O => clock_manager_clkin1
    );
  Inst_fm_modulator_ph_shift_15 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_15_Q,
      Q => Inst_fm_modulator_ph_shift_15_Q
    );
  Inst_fm_modulator_ph_shift_13 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_13_Q,
      Q => Inst_fm_modulator_ph_shift_13_Q
    );
  Inst_fm_modulator_ph_shift_12 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_12_Q,
      Q => Inst_fm_modulator_ph_shift_12_Q
    );
  Inst_fm_modulator_ph_shift_11 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_Q,
      Q => Inst_fm_modulator_ph_shift_11_Q
    );
  Inst_fm_modulator_ph_shift_10 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_Q,
      Q => Inst_fm_modulator_ph_shift_10_Q
    );
  Inst_fm_modulator_ph_shift_9 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_9_Q,
      Q => Inst_fm_modulator_ph_shift_9_Q
    );
  Inst_fm_modulator_ph_shift_8 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_8_Q,
      Q => Inst_fm_modulator_ph_shift_8_Q
    );
  Inst_fm_modulator_ph_shift_7 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_7_Q,
      Q => Inst_fm_modulator_ph_shift_7_Q
    );
  Inst_fm_modulator_ph_shift_6 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_6_Q,
      Q => Inst_fm_modulator_ph_shift_6_Q
    );
  Inst_fm_modulator_ph_shift_5 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_5_Q,
      Q => Inst_fm_modulator_ph_shift_5_Q
    );
  Inst_fm_modulator_ph_shift_4 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_4_Q,
      Q => Inst_fm_modulator_ph_shift_4_Q
    );
  Inst_fm_modulator_ph_shift_2 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => N0,
      Q => Inst_fm_modulator_ph_shift_2_Q
    );
  Inst_fm_modulator_ph_shift_data_12 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(8),
      Q => Inst_fm_modulator_ph_shift_data(12)
    );
  Inst_fm_modulator_ph_shift_data_11 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(7),
      Q => Inst_fm_modulator_ph_shift_data(11)
    );
  Inst_fm_modulator_ph_shift_data_10 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(6),
      Q => Inst_fm_modulator_ph_shift_data(10)
    );
  Inst_fm_modulator_ph_shift_data_9 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(5),
      Q => Inst_fm_modulator_ph_shift_data(9)
    );
  Inst_fm_modulator_ph_shift_data_8 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(4),
      Q => Inst_fm_modulator_ph_shift_data(8)
    );
  Inst_fm_modulator_ph_shift_data_7 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(3),
      Q => Inst_fm_modulator_ph_shift_data(7)
    );
  Inst_fm_modulator_ph_shift_data_6 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(2),
      Q => Inst_fm_modulator_ph_shift_data(6)
    );
  Inst_fm_modulator_ph_shift_data_5 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(1),
      Q => Inst_fm_modulator_ph_shift_data(5)
    );
  Inst_fm_modulator_ph_shift_data_4 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => audio_data_signed(0),
      Q => Inst_fm_modulator_ph_shift_data(4)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_8_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(7),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(8),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(8)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_8_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(7),
      DI => Inst_audio_dac_8bit_sum(8),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(8),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(8)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_8_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(8),
      I1 => Inst_audio_dac_8bit_unsigned_data(8),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(8)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_7_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(6),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(7),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(7)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_7_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(6),
      DI => Inst_audio_dac_8bit_sum(7),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(7),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(7)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_7_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(7),
      I1 => Inst_fm_modulator_ph_shift_data(11),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(7)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_6_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(5),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(6),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(6)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_6_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(5),
      DI => Inst_audio_dac_8bit_sum(6),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(6),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(6)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_6_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(6),
      I1 => Inst_fm_modulator_ph_shift_data(10),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(6)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_5_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(4),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(5),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(5)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_5_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(4),
      DI => Inst_audio_dac_8bit_sum(5),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(5),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(5)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_5_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(5),
      I1 => Inst_fm_modulator_ph_shift_data(9),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(5)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_4_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(3),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(4),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(4)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_4_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(3),
      DI => Inst_audio_dac_8bit_sum(4),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(4),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(4)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_4_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(4),
      I1 => Inst_fm_modulator_ph_shift_data(8),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(4)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_3_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(2),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(3),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(3)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_3_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(2),
      DI => Inst_audio_dac_8bit_sum(3),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(3),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(3)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_3_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(3),
      I1 => Inst_fm_modulator_ph_shift_data(7),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(3)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_2_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(1),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(2),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(2)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_2_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(1),
      DI => Inst_audio_dac_8bit_sum(2),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(2),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(2)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_2_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(2),
      I1 => Inst_fm_modulator_ph_shift_data(6),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(2)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_1_Q : XORCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(0),
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(1),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(1)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_1_Q : MUXCY
    port map (
      CI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(0),
      DI => Inst_audio_dac_8bit_sum(1),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(1),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(1)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_1_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(1),
      I1 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(1)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_xor_0_Q : XORCY
    port map (
      CI => N1,
      LI => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(0),
      O => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(0)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy_0_Q : MUXCY
    port map (
      CI => N1,
      DI => Inst_audio_dac_8bit_sum(0),
      S => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(0),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(0)
    );
  Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut_0_Q : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_audio_dac_8bit_sum(0),
      I1 => Inst_fm_modulator_ph_shift_data(4),
      O => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_lut(0)
    );
  Inst_audio_dac_8bit_sum_9 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_Madd_GND_16_o_GND_16_o_add_1_OUT_cy(8),
      Q => Inst_audio_dac_8bit_sum(9)
    );
  Inst_audio_dac_8bit_sum_8 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(8),
      Q => Inst_audio_dac_8bit_sum(8)
    );
  Inst_audio_dac_8bit_sum_7 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(7),
      Q => Inst_audio_dac_8bit_sum(7)
    );
  Inst_audio_dac_8bit_sum_6 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(6),
      Q => Inst_audio_dac_8bit_sum(6)
    );
  Inst_audio_dac_8bit_sum_5 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(5),
      Q => Inst_audio_dac_8bit_sum(5)
    );
  Inst_audio_dac_8bit_sum_4 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(4),
      Q => Inst_audio_dac_8bit_sum(4)
    );
  Inst_audio_dac_8bit_sum_3 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(3),
      Q => Inst_audio_dac_8bit_sum(3)
    );
  Inst_audio_dac_8bit_sum_2 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(2),
      Q => Inst_audio_dac_8bit_sum(2)
    );
  Inst_audio_dac_8bit_sum_1 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(1),
      Q => Inst_audio_dac_8bit_sum(1)
    );
  Inst_audio_dac_8bit_sum_0 : FD
    generic map(
      INIT => '0'
    )
    port map (
      C => clk_32,
      D => Inst_audio_dac_8bit_GND_16_o_GND_16_o_add_1_OUT(0),
      Q => Inst_audio_dac_8bit_sum(0)
    );
  Inst_audio_dac_8bit_unsigned_data_8 : FD
    port map (
      C => clk_32,
      D => douta(8),
      Q => Inst_audio_dac_8bit_unsigned_data(8)
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_51 : LUT2
    generic map(
      INIT => X"8"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(4),
      I1 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_bdd8
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_2 : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(11),
      I1 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0,
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_1 : LUT6
    generic map(
      INIT => X"AAA9AAA9AAA9A9A9"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(10),
      I1 => Inst_fm_modulator_ph_shift_data(9),
      I2 => Inst_fm_modulator_ph_shift_data(8),
      I3 => Inst_fm_modulator_ph_shift_data(7),
      I4 => Inst_fm_modulator_ph_shift_data(6),
      I5 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_bdd8,
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_11 : LUT6
    generic map(
      INIT => X"0000000101010101"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(10),
      I1 => Inst_fm_modulator_ph_shift_data(9),
      I2 => Inst_fm_modulator_ph_shift_data(8),
      I3 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_10_bdd8,
      I4 => Inst_fm_modulator_ph_shift_data(6),
      I5 => Inst_fm_modulator_ph_shift_data(7),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_12_1 : LUT3
    generic map(
      INIT => X"65"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(12),
      I1 => Inst_fm_modulator_ph_shift_data(11),
      I2 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0,
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_12_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_13_1 : LUT3
    generic map(
      INIT => X"20"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(12),
      I1 => Inst_fm_modulator_ph_shift_data(11),
      I2 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0,
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_13_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_15_1 : LUT3
    generic map(
      INIT => X"BF"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(11),
      I1 => Inst_fm_modulator_ph_shift_data(12),
      I2 => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_11_bdd0,
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_15_Q
    );
  Inst_fm_modulator_Madd_GND_18_o_ph_shift_data_31_add_0_OUT_xor_5_11 : LUT2
    generic map(
      INIT => X"6"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(5),
      I1 => Inst_fm_modulator_ph_shift_data(4),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_5_Q
    );
  GPIO0_OBUF : OBUF
    port map (
      I => GPIO0_OBUF_3,
      O => GPIO0
    );
  AUDIO1_RIGHT_OBUF : OBUF
    port map (
      I => Inst_audio_dac_8bit_sum(9),
      O => AUDIO1_RIGHT
    );
  AUDIO1_LEFT_OBUF : OBUF
    port map (
      I => Inst_audio_dac_8bit_sum(9),
      O => AUDIO1_LEFT
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_6_1 : LUT3
    generic map(
      INIT => X"95"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(6),
      I1 => Inst_fm_modulator_ph_shift_data(4),
      I2 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_6_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_7_1 : LUT4
    generic map(
      INIT => X"5666"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(7),
      I1 => Inst_fm_modulator_ph_shift_data(6),
      I2 => Inst_fm_modulator_ph_shift_data(4),
      I3 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_7_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_8_1 : LUT5
    generic map(
      INIT => X"99959595"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(8),
      I1 => Inst_fm_modulator_ph_shift_data(7),
      I2 => Inst_fm_modulator_ph_shift_data(6),
      I3 => Inst_fm_modulator_ph_shift_data(4),
      I4 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_8_Q
    );
  Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_9_1 : LUT6
    generic map(
      INIT => X"A9A9A999A999A999"
    )
    port map (
      I0 => Inst_fm_modulator_ph_shift_data(9),
      I1 => Inst_fm_modulator_ph_shift_data(8),
      I2 => Inst_fm_modulator_ph_shift_data(7),
      I3 => Inst_fm_modulator_ph_shift_data(6),
      I4 => Inst_fm_modulator_ph_shift_data(4),
      I5 => Inst_fm_modulator_ph_shift_data(5),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_9_Q
    );
  Mxor_audio_data_signed_8_xo_0_1_INV_0 : INV
    port map (
      I => douta(8),
      O => audio_data_signed(8)
    );
  Inst_fm_modulator_Madd_GND_18_o_ph_shift_data_31_add_0_OUT_xor_4_11_INV_0 : INV
    port map (
      I => Inst_fm_modulator_ph_shift_data(4),
      O => Inst_fm_modulator_GND_18_o_ph_shift_data_31_add_0_OUT_4_Q
    );
  addr_counter1 : counter
    port map (
      clk => clk_32,
      q(27) => addr_counter(27),
      q(26) => addr_counter(26),
      q(25) => addr_counter(25),
      q(24) => addr_counter(24),
      q(23) => addr_counter(23),
      q(22) => addr_counter(22),
      q(21) => addr_counter(21),
      q(20) => addr_counter(20),
      q(19) => addr_counter(19),
      q(18) => addr_counter(18),
      q(17) => addr_counter(17),
      q(16) => addr_counter(16),
      q(15) => addr_counter(15),
      q(14) => addr_counter(14),
      q(13) => addr_counter(13),
      q(12) => addr_counter(12),
      q(11) => NLW_addr_counter1_q_11_UNCONNECTED,
      q(10) => NLW_addr_counter1_q_10_UNCONNECTED,
      q(9) => NLW_addr_counter1_q_9_UNCONNECTED,
      q(8) => NLW_addr_counter1_q_8_UNCONNECTED,
      q(7) => NLW_addr_counter1_q_7_UNCONNECTED,
      q(6) => NLW_addr_counter1_q_6_UNCONNECTED,
      q(5) => NLW_addr_counter1_q_5_UNCONNECTED,
      q(4) => NLW_addr_counter1_q_4_UNCONNECTED,
      q(3) => NLW_addr_counter1_q_3_UNCONNECTED,
      q(2) => NLW_addr_counter1_q_2_UNCONNECTED,
      q(1) => NLW_addr_counter1_q_1_UNCONNECTED,
      q(0) => NLW_addr_counter1_q_0_UNCONNECTED
    );
  waveform_rom : rom_memory
    port map (
      clka => clk_32,
      addra(15) => addr_counter(27),
      addra(14) => addr_counter(26),
      addra(13) => addr_counter(25),
      addra(12) => addr_counter(24),
      addra(11) => addr_counter(23),
      addra(10) => addr_counter(22),
      addra(9) => addr_counter(21),
      addra(8) => addr_counter(20),
      addra(7) => addr_counter(19),
      addra(6) => addr_counter(18),
      addra(5) => addr_counter(17),
      addra(4) => addr_counter(16),
      addra(3) => addr_counter(15),
      addra(2) => addr_counter(14),
      addra(1) => addr_counter(13),
      addra(0) => addr_counter(12),
      douta(8) => douta(8),
      douta(7) => audio_data_signed(7),
      douta(6) => audio_data_signed(6),
      douta(5) => audio_data_signed(5),
      douta(4) => audio_data_signed(4),
      douta(3) => audio_data_signed(3),
      douta(2) => audio_data_signed(2),
      douta(1) => audio_data_signed(1),
      douta(0) => audio_data_signed(0)
    );
  Inst_fm_modulator_fast_adder : phase_adder
    port map (
      clk => clk_272,
      a(31) => GPIO0_OBUF_3,
      a(30) => Inst_fm_modulator_sum(30),
      a(29) => Inst_fm_modulator_sum(29),
      a(28) => Inst_fm_modulator_sum(28),
      a(27) => Inst_fm_modulator_sum(27),
      a(26) => Inst_fm_modulator_sum(26),
      a(25) => Inst_fm_modulator_sum(25),
      a(24) => Inst_fm_modulator_sum(24),
      a(23) => Inst_fm_modulator_sum(23),
      a(22) => Inst_fm_modulator_sum(22),
      a(21) => Inst_fm_modulator_sum(21),
      a(20) => Inst_fm_modulator_sum(20),
      a(19) => Inst_fm_modulator_sum(19),
      a(18) => Inst_fm_modulator_sum(18),
      a(17) => Inst_fm_modulator_sum(17),
      a(16) => Inst_fm_modulator_sum(16),
      a(15) => Inst_fm_modulator_sum(15),
      a(14) => Inst_fm_modulator_sum(14),
      a(13) => Inst_fm_modulator_sum(13),
      a(12) => Inst_fm_modulator_sum(12),
      a(11) => Inst_fm_modulator_sum(11),
      a(10) => Inst_fm_modulator_sum(10),
      a(9) => Inst_fm_modulator_sum(9),
      a(8) => Inst_fm_modulator_sum(8),
      a(7) => Inst_fm_modulator_sum(7),
      a(6) => Inst_fm_modulator_sum(6),
      a(5) => Inst_fm_modulator_sum(5),
      a(4) => Inst_fm_modulator_sum(4),
      a(3) => Inst_fm_modulator_sum(3),
      a(2) => Inst_fm_modulator_sum(2),
      a(1) => Inst_fm_modulator_sum(1),
      a(0) => Inst_fm_modulator_sum(0),
      b(31) => N1,
      b(30) => Inst_fm_modulator_ph_shift_2_Q,
      b(29) => N1,
      b(28) => N1,
      b(27) => Inst_fm_modulator_ph_shift_2_Q,
      b(26) => N1,
      b(25) => Inst_fm_modulator_ph_shift_2_Q,
      b(24) => Inst_fm_modulator_ph_shift_2_Q,
      b(23) => Inst_fm_modulator_ph_shift_2_Q,
      b(22) => Inst_fm_modulator_ph_shift_2_Q,
      b(21) => N1,
      b(20) => N1,
      b(19) => N1,
      b(18) => N1,
      b(17) => Inst_fm_modulator_ph_shift_2_Q,
      b(16) => N1,
      b(15) => Inst_fm_modulator_ph_shift_15_Q,
      b(14) => Inst_fm_modulator_ph_shift_13_Q,
      b(13) => Inst_fm_modulator_ph_shift_13_Q,
      b(12) => Inst_fm_modulator_ph_shift_12_Q,
      b(11) => Inst_fm_modulator_ph_shift_11_Q,
      b(10) => Inst_fm_modulator_ph_shift_10_Q,
      b(9) => Inst_fm_modulator_ph_shift_9_Q,
      b(8) => Inst_fm_modulator_ph_shift_8_Q,
      b(7) => Inst_fm_modulator_ph_shift_7_Q,
      b(6) => Inst_fm_modulator_ph_shift_6_Q,
      b(5) => Inst_fm_modulator_ph_shift_5_Q,
      b(4) => Inst_fm_modulator_ph_shift_4_Q,
      b(3) => Inst_fm_modulator_ph_shift_2_Q,
      b(2) => Inst_fm_modulator_ph_shift_2_Q,
      b(1) => N1,
      b(0) => N1,
      s(31) => GPIO0_OBUF_3,
      s(30) => Inst_fm_modulator_sum(30),
      s(29) => Inst_fm_modulator_sum(29),
      s(28) => Inst_fm_modulator_sum(28),
      s(27) => Inst_fm_modulator_sum(27),
      s(26) => Inst_fm_modulator_sum(26),
      s(25) => Inst_fm_modulator_sum(25),
      s(24) => Inst_fm_modulator_sum(24),
      s(23) => Inst_fm_modulator_sum(23),
      s(22) => Inst_fm_modulator_sum(22),
      s(21) => Inst_fm_modulator_sum(21),
      s(20) => Inst_fm_modulator_sum(20),
      s(19) => Inst_fm_modulator_sum(19),
      s(18) => Inst_fm_modulator_sum(18),
      s(17) => Inst_fm_modulator_sum(17),
      s(16) => Inst_fm_modulator_sum(16),
      s(15) => Inst_fm_modulator_sum(15),
      s(14) => Inst_fm_modulator_sum(14),
      s(13) => Inst_fm_modulator_sum(13),
      s(12) => Inst_fm_modulator_sum(12),
      s(11) => Inst_fm_modulator_sum(11),
      s(10) => Inst_fm_modulator_sum(10),
      s(9) => Inst_fm_modulator_sum(9),
      s(8) => Inst_fm_modulator_sum(8),
      s(7) => Inst_fm_modulator_sum(7),
      s(6) => Inst_fm_modulator_sum(6),
      s(5) => Inst_fm_modulator_sum(5),
      s(4) => Inst_fm_modulator_sum(4),
      s(3) => Inst_fm_modulator_sum(3),
      s(2) => Inst_fm_modulator_sum(2),
      s(1) => Inst_fm_modulator_sum(1),
      s(0) => Inst_fm_modulator_sum(0)
    );

end Structure;

-- synthesis translate_on
