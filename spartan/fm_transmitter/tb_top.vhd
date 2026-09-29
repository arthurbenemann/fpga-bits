LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
--USE ieee.numeric_std.ALL;
 
ENTITY tb_top IS
END tb_top;
 
ARCHITECTURE behavior OF tb_top IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT topModule
    PORT(
         CLK : IN  std_logic;
         GPIO0 : OUT  std_logic;
         AUDIO1_RIGHT : OUT  std_logic;
         AUDIO1_LEFT : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';

 	--Outputs
   signal GPIO0 : std_logic;
   signal AUDIO1_RIGHT : std_logic;
   signal AUDIO1_LEFT : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 31.25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: topModule PORT MAP (
          CLK => CLK,
          GPIO0 => GPIO0,
          AUDIO1_RIGHT => AUDIO1_RIGHT,
          AUDIO1_LEFT => AUDIO1_LEFT
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
