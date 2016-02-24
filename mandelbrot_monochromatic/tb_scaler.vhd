
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY tb_scaler IS
END tb_scaler;
 
ARCHITECTURE behavior OF tb_scaler IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT pixel_scaling
    PORT(
         x_pixel : IN  std_logic_vector(10 downto 0);
         y_pixel : IN  std_logic_vector(9 downto 0);
         x0 : OUT  std_logic_vector(17 downto 0);
         y0 : OUT  std_logic_vector(17 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal x_pixel : std_logic_vector(10 downto 0) := (others => '0');
   signal y_pixel : std_logic_vector(9 downto 0) := (others => '0');

 	--Outputs
   signal x0 : std_logic_vector(17 downto 0);
   signal y0 : std_logic_vector(17 downto 0);
   -- No clocks detected in port list. Replace <clock> below with 
   -- appropriate port name 
 
   constant period : time := 1 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: pixel_scaling PORT MAP (
          x_pixel => x_pixel,
          y_pixel => y_pixel,
          x0 => x0,
          y0 => y0
        );
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	
		
		stimloop : for i in 0 to 799 loop
			wait for period;
				x_pixel <= std_logic_vector(to_unsigned(i, x_pixel'length));
				y_pixel <= std_logic_vector(to_unsigned(i, y_pixel'length)); 
			wait for period;
		end loop stimloop;


      wait;
   end process;

END;
