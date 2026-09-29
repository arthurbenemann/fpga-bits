LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
  
ENTITY tb_ms_clock IS
END tb_ms_clock;
 
ARCHITECTURE behavior OF tb_ms_clock IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT ms_timer
    PORT(
         clk : IN  std_logic;
         clk_1ms : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';

 	--Outputs
   signal clk_1ms : std_logic;

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: ms_timer PORT MAP (
          clk => clk,
          clk_1ms => clk_1ms
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
