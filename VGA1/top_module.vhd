library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_module is Port ( 
	CLK : in  STD_LOGIC;
	VGA_RED : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_GREEN : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_BLUE : out STD_LOGIC_VECTOR(3 downto 0);
	VGA_VSYNC : out STD_LOGIC;
	VGA_HSYNC : out STD_LOGIC;
	SW : in std_logic_vector(0 downto 0));
end top_module;

architecture Behavioral of top_module is
	component vga800x600 port(
		clk : IN std_logic;          
		red : OUT std_logic_vector(3 downto 0);
		green : OUT std_logic_vector(3 downto 0);
		blue : OUT std_logic_vector(3 downto 0);
		vsync : OUT std_logic;
		hsync : OUT std_logic;
		SW : IN std_logic);
	end component;
	
	component clock_manager port (
		CLK_IN1 : in std_logic;
		pixel_clock : out std_logic);
	end component;

 	signal rgb : std_logic_vector (11 downto 0);
	signal pixel_clock : std_logic;
begin
	
	pll1: clock_manager port map (
		CLK_IN1 => CLK,
		pixel_clock => pixel_clock
	);


	vga1: vga800x600 PORT MAP(
		clk => pixel_clock,
		red => VGA_RED,
		green => VGA_GREEN,
		blue => VGA_BLUE,
		vsync => VGA_VSYNC,
		hsync => VGA_HSYNC ,
		SW => SW(0)
	);

end Behavioral;

