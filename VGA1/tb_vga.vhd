--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:56:06 02/20/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/FPGA_temp/VGA/tb_vga.vhd
-- Project Name:  VGA
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: VGA
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
 
ENTITY tb_vga IS
END tb_vga;
 
ARCHITECTURE behavior OF tb_vga IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT VGA
    PORT(
         clk : IN  std_logic;
         red : OUT  std_logic_vector(3 downto 0);
         green : OUT  std_logic_vector(3 downto 0);
         blue : OUT  std_logic_vector(3 downto 0);
         hsync : OUT  std_logic;
         vsync : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';

 	--Outputs
   signal red : std_logic_vector(3 downto 0);
   signal green : std_logic_vector(3 downto 0);
   signal blue : std_logic_vector(3 downto 0);
   signal hsync : std_logic;
   signal vsync : std_logic;

   -- Clock period definitions
   constant clk_period : time := 25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: VGA PORT MAP (
          clk => clk,
          red => red,
          green => green,
          blue => blue,
          hsync => hsync,
          vsync => vsync
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
