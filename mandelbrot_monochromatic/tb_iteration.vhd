--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   18:54:00 02/23/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/GitHub/fpga-bits/mandelbrot_monochromatic/tb_iteration.vhd
-- Project Name:  mandelbrot_monochromatic
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: iteration
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
 
ENTITY tb_iteration IS
END tb_iteration;
 
ARCHITECTURE behavior OF tb_iteration IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT iteration
    PORT(
         clk : IN  std_logic;
         x : IN  std_logic_vector(17 downto 0);
         y : IN  std_logic_vector(17 downto 0);
         x0 : IN  std_logic_vector(17 downto 0);
         y0 : IN  std_logic_vector(17 downto 0);
         x_out : OUT  std_logic_vector(17 downto 0);
         y_out : OUT  std_logic_vector(17 downto 0);
         ov : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal x : std_logic_vector(17 downto 0) := "00"& x"1000";
   signal y : std_logic_vector(17 downto 0) := "00"& x"0000";
   signal x0 : std_logic_vector(17 downto 0) := (others => '0');
   signal y0 : std_logic_vector(17 downto 0) := (others => '0');

 	--Outputs
   signal x_out : std_logic_vector(17 downto 0);
   signal y_out : std_logic_vector(17 downto 0);
   signal ov : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: iteration PORT MAP (
          clk => clk,
          x => x,
          y => y,
          x0 => x0,
          y0 => y0,
          x_out => x_out,
          y_out => y_out,
          ov => ov
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

      wait for clk_period*10.5;

      -- insert stimulus here 
		wait for 100ns;
		x <= "01"& x"0000";
		
		wait for 50ns;
		y <= "00"& x"1000";
		
      wait;
   end process;

END;
