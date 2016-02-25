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

entity mandel_mono is port ( 
	CLK : in  std_logic;
	SW : in std_logic_vector(7 downto 0);	
	VGA_RED : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_GREEN : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_BLUE : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_VSYNC : out STD_LOGIC;
	VGA_HSYNC : out STD_LOGIC;
	LED : out std_logic_vector(7 downto 0));
end mandel_mono;

architecture Behavioral of mandel_mono is

	component clock_manager	port(
	  CLK_IN1           : in     std_logic;
	  CLK_80          : out    std_logic;
	  CLK_40          : out    std_logic
	 );
	end component;
	
	signal CLK_80 : std_logic;
	signal CLK_40 : std_logic;	

	component pixel_gen port ( 
		clk : in  std_logic;
		x_pixel : in std_logic_vector(10 downto 0);
		y_pixel : in std_logic_vector(9 downto 0);
		color : out std_logic_vector(3 downto 0));
	end component;
	
	signal color : std_logic_vector(3 downto 0);
	signal color_rgb : std_logic_vector(11 downto 0);
	signal x_pixel : std_logic_vector(10 downto 0);
	signal y_pixel : std_logic_vector(9 downto 0);
	

	component vga800x600 port( 
		clk : IN std_logic;      
		color : in std_logic_vector(11 downto 0);
		h : out std_logic_vector(10 downto 0);
		v : out std_logic_vector(9 downto 0);
		red : OUT std_logic_vector(3 downto 0);
		green : OUT std_logic_vector(3 downto 0);
		blue : OUT std_logic_vector(3 downto 0);
		hsync : OUT std_logic;
		vsync : OUT std_logic);
	end component;
	
begin
	
	LED <= SW;
	
	clock_manager1 : clock_manager port map(
		CLK_IN1 => CLK,
		CLK_80 => CLK_80,
		CLK_40 => CLK_40
	);
		
	pixel : pixel_gen port map(
		clk => CLK_80,
		x_pixel => x_pixel,
		y_pixel => y_pixel,
		color => color
	);
	
	--color_rgb <= color & color & color; -- monochromatic mapping
	
	with color select color_rgb <= -- rgb palette
		x"00f" when "1000",
		x"0f0" when "1100",
		x"f00" when "1110",
		x"fff" when "1111",
		x"000" when others;


		
	vga_port: vga800x600 port  map(
		clk => CLK_40,	
		-- input
		color => color_rgb,
		-- logical interface
		h => x_pixel,
		v => y_pixel,
		-- physical interface
		red => VGA_RED,
		green => VGA_GREEN,
		blue => VGA_BLUE,
		vsync => VGA_VSYNC,
		hsync => VGA_HSYNC
	);

end Behavioral;

