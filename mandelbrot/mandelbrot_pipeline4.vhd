--
-- Pipeline of 4 mandelbrot iteration blocks
--
-- * 4x latency of each block (total of 28 cycles)
-- * no registers

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

entity mandelbrot_pipeline4 is port (
	clk : IN  std_logic;
	ov_in : in std_logic; 
	x,y,x0,y0 : IN std_logic_vector(17 downto 0);   
	x_out,y_out,x0_out,y0_out : OUT std_logic_vector(17 downto 0);
	ov : OUT std_logic_vector (3 downto 0));
end mandelbrot_pipeline4;

architecture Behavioral of mandelbrot_pipeline4 is

	component mandelbrot_iteration port(
		clk : IN  std_logic;
		ov_in : in std_logic; 
		x,y,x0,y0 : IN std_logic_vector(17 downto 0);   
		x_out,y_out,x0_out,y0_out : OUT std_logic_vector(17 downto 0);
		ov : OUT std_logic);
	end component;
	
	signal x1,x2,x3,x0_1,x0_2,x0_3 : std_logic_vector (17 downto 0);
	signal y1,y2,y3,y0_1,y0_2,y0_3 : std_logic_vector (17 downto 0);
	signal o1,o2,o3,o4 : std_logic;
	
begin

	iteration1 : mandelbrot_iteration port map(
		clk => clk,
		ov_in => ov_in,
		x => x, y => y, x0 => x0, y0 => y0,     -- inputs
		x_out => x1, y_out => y1, ov => o1,       -- outputs
		x0_out=> x0_1, y0_out => y0_1
	);
		
	iteration2 : mandelbrot_iteration port map(
		clk => clk,
		ov_in => o1,
		x => x1, y => y1, x0 => x0_1, y0 => y0_1, -- inputs
		x_out => x2, y_out => y2, ov => o2,       -- outputs
		x0_out=> x0_2, y0_out => y0_2
	);
	
	iteration3 : mandelbrot_iteration port map(
		clk => clk,
		ov_in => o2,
		x => x2, y => y2, x0 => x0_2, y0 => y0_2, -- inputs
		x_out => x3, y_out => y3, ov => o3,       -- outputs
		x0_out=> x0_3, y0_out => y0_3
	);
	
	iteration4 : mandelbrot_iteration port map(
		clk => clk,
		ov_in => o3,
		x => x3, y => y3, x0 => x0_3, y0 => y0_3, -- inputs
		x_out => x_out, y_out => y_out, ov => o4,   -- outputs
		x0_out=> x0_out, y0_out => y0_out
	);
	
	ov <= o1 & o2 & o3 & o4;

end Behavioral;

