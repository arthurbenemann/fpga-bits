LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY tb_clock24h_bdc IS
END tb_clock24h_bdc;
 
ARCHITECTURE behavior OF tb_clock24h_bdc IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT clock24h_bcd
    PORT(
         clk_1ms : IN  std_logic;
         hour_bcd : OUT  std_logic_vector(7 downto 0);
         minute_bcd : OUT  std_logic_vector(7 downto 0);
         clk_1s : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk_1ms : std_logic := '0';

 	--Outputs
   signal hour_bcd : std_logic_vector(7 downto 0);
   signal minute_bcd : std_logic_vector(7 downto 0);
   signal clk_1s : std_logic;

   -- Clock period definitions
   constant clk_1ms_period : time := 1 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: clock24h_bcd PORT MAP (
          clk_1ms => clk_1ms,
          hour_bcd => hour_bcd,
          minute_bcd => minute_bcd,
          clk_1s => clk_1s
        );

   -- Clock process definitions
   clk_1ms_process :process
   begin
		clk_1ms <= '0';
		wait for clk_1ms_period/2;
		clk_1ms <= '1';
		wait for clk_1ms_period/2;
   end process;
 
   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_1ms_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
