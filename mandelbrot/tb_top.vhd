--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   00:22:43 02/25/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/GitHub/fpga-bits/mandelbrot_monochromatic/tb_top.vhd
-- Project Name:  mandelbrot_monochromatic
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: mandel_mono
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_top IS
END tb_top;
 
ARCHITECTURE behavior OF tb_top IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT mandel_mono
    PORT(
         CLK : IN  std_logic;
         SW : IN  std_logic_vector(7 downto 0);
         DIR_UP : IN  std_logic;
         DIR_DOWN : IN  std_logic;
         DIR_LEFT : IN  std_logic;
         DIR_RIGHT : IN  std_logic;
         VGA_RED : OUT  std_logic_vector(3 downto 0);
         VGA_GREEN : OUT  std_logic_vector(3 downto 0);
         VGA_BLUE : OUT  std_logic_vector(3 downto 0);
         VGA_VSYNC : OUT  std_logic;
         VGA_HSYNC : OUT  std_logic;
         LED : OUT  std_logic_vector(7 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal SW : std_logic_vector(7 downto 0) := (others => '0');
   signal DIR_UP : std_logic := '0';
   signal DIR_DOWN : std_logic := '0';
   signal DIR_LEFT : std_logic := '0';
   signal DIR_RIGHT : std_logic := '0';

 	--Outputs
   signal VGA_RED : std_logic_vector(3 downto 0);
   signal VGA_GREEN : std_logic_vector(3 downto 0);
   signal VGA_BLUE : std_logic_vector(3 downto 0);
   signal VGA_VSYNC : std_logic;
   signal VGA_HSYNC : std_logic;
   signal LED : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant CLK_period : time := 31.25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: mandel_mono PORT MAP (
          CLK => CLK,
          SW => SW,
          DIR_UP => DIR_UP,
          DIR_DOWN => DIR_DOWN,
          DIR_LEFT => DIR_LEFT,
          DIR_RIGHT => DIR_RIGHT,
          VGA_RED => VGA_RED,
          VGA_GREEN => VGA_GREEN,
          VGA_BLUE => VGA_BLUE,
          VGA_VSYNC => VGA_VSYNC,
          VGA_HSYNC => VGA_HSYNC,
          LED => LED
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for CLK_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
