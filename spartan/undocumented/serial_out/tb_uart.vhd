--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   17:34:36 02/22/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/FPGA_temp/serial_out/tb_uart.vhd
-- Project Name:  serial_out
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: uart
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
 
ENTITY tb_uart IS
END tb_uart;
 
ARCHITECTURE behavior OF tb_uart IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT uart
    PORT(
		clk : in  std_logic;
		tx_data : in std_logic_vector(7 downto 0);
		tx_en : in std_logic;
		tx_ready : out std_logic;
		tx  : out std_logic); 
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal tx_data : std_logic_vector(7 downto 0) := "10101011";
   signal tx_en : std_logic := '0';

 	--Outputs
   signal tx_ready : std_logic;
   signal tx : std_logic;

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: uart PORT MAP (
          clk => clk,
			 tx_en => tx_en,
          tx_data => tx_data,
          tx_ready => tx_ready,
          tx => tx
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
		wait for 5 us;	
       -- insert stimulus here 
		
		tx_en <= '1';
		wait for 5 us;
		tx_en <= '0';
		wait for 120 us;
		tx_en <= '1';
		wait for 100 us;
		tx_en <= '0';
		wait for 300 us;

   end process;

END;
