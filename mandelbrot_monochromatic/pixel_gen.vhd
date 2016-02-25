library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pixel_gen is port ( 
	clk : in  std_logic;
	x0,y0 : in std_logic_vector(17 downto 0);
	color : out std_logic_vector(3 downto 0));
end pixel_gen;

architecture Behavioral of pixel_gen is

	component mandelbrot_pipeline4 port(
		clk : IN  std_logic;
		ov_in : in std_logic; 
		x,y,x0,y0 : IN std_logic_vector(17 downto 0);   
		x_out,y_out,x0_out,y0_out : OUT std_logic_vector(17 downto 0);
		ov : out std_logic_vector (3 downto 0));
	end component;
	
	signal overflow : std_logic_vector (3 downto 0);
	
begin
	
	pipeline : mandelbrot_pipeline4 port map(
		clk => clk,
		ov_in => '0',
		x => x0, y => y0, x0 => x0, y0 => y0,     -- inputs
		x_out => open, y_out => open, ov => overflow, -- outputs
		x0_out=> open, y0_out => open
	);
	
	color <= not (overflow);
	
end Behavioral;

