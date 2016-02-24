LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
 
ENTITY tb_iteration IS
END tb_iteration;
 
ARCHITECTURE behavior OF tb_iteration IS 
 

    COMPONENT mandelbrot_iteration
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
   signal x : std_logic_vector(17 downto 0) := (others => '0');
   signal y : std_logic_vector(17 downto 0) := (others => '0');
   signal x0 : std_logic_vector(17 downto 0) := (others => '0');
   signal y0 : std_logic_vector(17 downto 0) := (others => '0');

 	--Outputs
   signal x_out : std_logic_vector(17 downto 0);
   signal y_out : std_logic_vector(17 downto 0);
   signal ov : std_logic;

   -- Clock period definitions
   constant clk_period : time := 12.5 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: mandelbrot_iteration PORT MAP (
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

      wait for clk_period*10;

      -- insert stimulus here 
		
		x0<= std_logic_vector(to_signed(+1*(2**15),18));
		y0<= std_logic_vector(to_signed(+0*(2**15),18));
		
		x <= std_logic_vector(to_signed(+1*(2**15),18));
		y <= std_logic_vector(to_signed(+0*(2**15),18));
      wait for clk_period*10;
		
		x <= std_logic_vector(to_signed(-1*(2**15),18));
		y <= std_logic_vector(to_signed(+0*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(+0*(2**15),18));
		y <= std_logic_vector(to_signed(+1*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(+0*(2**15),18));
		y <= std_logic_vector(to_signed(-1*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(+1*(2**15),18));
		y <= std_logic_vector(to_signed(+1*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(-1*(2**15),18));
		y <= std_logic_vector(to_signed(-1*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(+1*(2**15),18));
		y <= std_logic_vector(to_signed(-1*(2**15),18));
      wait for clk_period*10;

		x <= std_logic_vector(to_signed(-1*(2**15),18));
		y <= std_logic_vector(to_signed(1*(2**15),18));
      wait for clk_period*10;
		
		x <= std_logic_vector(to_signed(2*(2**15),18));
		y <= std_logic_vector(to_signed(1*(2**15),18));
      wait for clk_period*10;
		
		x <= std_logic_vector(to_signed(2*(2**15),18));
		y <= std_logic_vector(to_signed(2*(2**15),18));
      wait for clk_period*10;


      wait;
   end process;

END;
