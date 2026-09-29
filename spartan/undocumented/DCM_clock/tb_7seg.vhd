LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
  
ENTITY tb_7seg IS
END tb_7seg;
 
ARCHITECTURE behavior OF tb_7seg IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT seven_seg
    PORT(
         display1 : IN  std_logic_vector(3 downto 0);
         display2 : IN  std_logic_vector(3 downto 0);
         display3 : IN  std_logic_vector(3 downto 0);
         display4 : IN  std_logic_vector(3 downto 0);
         clk : IN  std_logic;
         anodes : INOUT  std_logic_vector(4 downto 0);
         sevenseg : OUT  std_logic_vector(7 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';

	--BiDirs
   signal anodes : std_logic_vector(4 downto 0);

 	--Outputs
   signal sevenseg : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: seven_seg PORT MAP (
          display1 => x"1",
          display2 => x"2",
          display3 => x"3",
          display4 => x"4",
          clk => clk,
          anodes => anodes,
          sevenseg => sevenseg
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
