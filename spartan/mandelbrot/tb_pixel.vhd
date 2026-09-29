--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   00:53:43 02/25/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/GitHub/fpga-bits/mandelbrot_monochromatic/tb_pixel.vhd
-- Project Name:  mandelbrot_monochromatic
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: pixel_gen
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
USE ieee.numeric_std.ALL;
 
ENTITY tb_pixel IS
END tb_pixel;
 
ARCHITECTURE behavior OF tb_pixel IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT pixel_gen
    PORT(
         clk : IN  std_logic;
         x0 : IN  std_logic_vector(17 downto 0);
         y0 : IN  std_logic_vector(17 downto 0);
         color : OUT  std_logic_vector(3 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal x0 : std_logic_vector(17 downto 0) := (others => '0');
   signal y0 : std_logic_vector(17 downto 0) := (others => '0');

 	--Outputs
   signal color : std_logic_vector(3 downto 0);

   -- Clock period definitions
   constant clk_period : time := 1 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: pixel_gen PORT MAP (
          clk => clk,
          x0 => x0,
          y0 => y0,
          color => color
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

      wait for clk_period*100.5;

      -- insert stimulus here 
		y0 <= std_logic_vector(to_signed(2*(2**15),18));
		--y0 <= std_logic_vector(to_signed(1*(2**13),18));
		
      wait;
   end process;

END;
