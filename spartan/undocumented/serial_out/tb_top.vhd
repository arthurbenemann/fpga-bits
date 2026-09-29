--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   10:59:29 02/23/2016
-- Design Name:   
-- Module Name:   C:/Users/Arthur/Documents/FPGA_temp/serial_out/tb_top.vhd
-- Project Name:  serial_out
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: topModule
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
 
    COMPONENT topModule
    PORT(
         CLK : IN  std_logic;
         GPIO0 : OUT  std_logic;
         GPIO1 : OUT  std_logic;
         RX : IN  std_logic;
         TX : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RX : std_logic := '1';

 	--Outputs
   signal GPIO0 : std_logic;
   signal GPIO1 : std_logic;
   signal TX : std_logic;

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
   constant bit_period : time := 8.68 us;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: topModule PORT MAP (
          CLK => CLK,
          GPIO0 => GPIO0,
          GPIO1 => GPIO1,
          RX => RX,
          TX => TX
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
		rx <= '1'; 	-- stop bit
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
