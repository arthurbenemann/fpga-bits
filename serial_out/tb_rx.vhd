--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   10:34:16 02/23/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/FPGA_temp/serial_out/tb_rx.vhd
-- Project Name:  serial_out
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: uart_rx
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
 
ENTITY tb_rx IS
END tb_rx;
 
ARCHITECTURE behavior OF tb_rx IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT uart_rx
    PORT(
         clk : IN  std_logic;
         rx : IN  std_logic;
         rx_data : OUT  std_logic_vector(7 downto 0);
         rx_ready : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rx : std_logic := '1';

 	--Outputs
   signal rx_data : std_logic_vector(7 downto 0);
   signal rx_ready : std_logic;

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
   constant bit_period : time := 8.68 us;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: uart_rx PORT MAP (
          clk => clk,
          rx => rx,
          rx_data => rx_data,
          rx_ready => rx_ready
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

      wait for 10 us;
		
		-- send '0000000'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '0';	-- data
		wait for bit_period*8;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;
		
		wait for 50 us;
		
		-- send '11111111'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '1';	-- data
		wait for bit_period*8;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;

		wait for 50 us;	

		-- send '11110000'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;
		
		wait for 50 us;	

		-- send '00001111'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '0'; 	-- stop bit
		wait for bit_period*1;

		wait for 50 us;
				
		-- send '01010101'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;
		
		
		-- send '10101010'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;
		
		-- send '01010101'
		rx <= '0';	-- start bit
		wait for bit_period*1;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1';	-- data
		wait for bit_period;
		rx <= '0';	-- data
		wait for bit_period;
		rx <= '1'; 	-- stop bit
		wait for bit_period*1;
		
		wait for 200 us;
		
   end process;

END;
