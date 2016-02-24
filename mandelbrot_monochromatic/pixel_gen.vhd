--
-- Monochromatic Mandelbrot set on VGA interface
--
-- This project is trying to generate a mandelbrot set without using external memmory. There
-- are two ways in which this might be viable:
-- * VGA with 400*300*4bit = 480 kb monochromatic interface which would fit in the 576 kb of internal RAM
-- * Reduce the number of iterations to generate the pixels in real time
--
-- The pseudo-code for each iteration is:
-- 	xout = x*x - y*y + x0
--		yout = 2*x*y + y0
-- 	overflow = x*x + y*y > 2*2  
--
-- Data is stored in Q2.16 as the spartan 6 DSP blocks can do 18x18 multiplication


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pixel_gen is port ( 
	clk : in  std_logic;
	x_pixel : in std_logic_vector(10 downto 0);
	y_pixel : in std_logic_vector(9 downto 0);
	color : out std_logic_vector(3 downto 0));
end pixel_gen;

architecture Behavioral of pixel_gen is

--	component iteration port(
--		clk : in  std_logic;
--		x : in std_logic_vector (17 downto 0);
--		y : in std_logic_vector (17 downto 0);
--		x0 : in std_logic_vector (17 downto 0);
--		y0 : in std_logic_vector (17 downto 0);
--		x_out : out std_logic_vector (17 downto 0);
--		y_out : out std_logic_vector (17 downto 0);
--		ov : out std_logic);
--	end component;

	component mandelbrot_iteration port(
		clk : IN  std_logic;
		x : IN std_logic_vector(17 downto 0);
		y : IN std_logic_vector(17 downto 0);
		x0 : IN std_logic_vector(17 downto 0);
		y0 : IN std_logic_vector(17 downto 0);          
		x_out : OUT std_logic_vector(17 downto 0);
		y_out : OUT std_logic_vector(17 downto 0);
		ov : OUT std_logic
		);
	end component;
	
	signal zero : std_logic_vector (17 downto 0) :=  "00" & x"0000";
	
	signal x0 : std_logic_vector (17 downto 0);
	signal y0 : std_logic_vector (17 downto 0);
	
	signal x1,x2,x3 : std_logic_vector (17 downto 0);
	signal y1,y2,y3 : std_logic_vector (17 downto 0);
	signal o1,o2,o3 : std_logic;
	
begin
	x0 <= x_pixel & x_pixel(6 downto 0);
	y0 <= y_pixel & y_pixel(7 downto 0);
	
	--y1 <= x0 and y0;
	--o1 <= y1(0);
	
	
--	iteration1: mandelbrot_iteration port map(
--		x => zero,
--		y => zero,
--		x0 => x0,
--		y0 => y0,
--		x_out => x1,
--		y_out => y1,
--		ov => o1 
--	);

	iteration1 : mandelbrot_iteration port map(
		clk => clk,
		x => x0, y => y0, x0 => x0, y0 => y0, -- inputs
		x_out => x1, y_out => y1, ov => o1    -- outputs
	);
		
	iteration2 : mandelbrot_iteration port map(
		clk => clk,
		x => x1, y => y1, x0 => x0, y0 => y0, -- inputs
		x_out => x2, y_out => y2, ov => o2    -- outputs
	);
	
	iteration3 : mandelbrot_iteration port map(
		clk => clk,
		x => x2, y => y2, x0 => x0, y0 => y0, -- inputs
		x_out => x3, y_out => y3, ov => o3    -- outputs
	);
	

	color <= o1 & o2 & o3 & o3;

--	color <= o1 & o1 & o1 & o1;
end Behavioral;

