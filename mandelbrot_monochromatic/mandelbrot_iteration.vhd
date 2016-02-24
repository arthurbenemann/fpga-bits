library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity mandelbrot_iteration is port(
	clk : in  std_logic;
	-- inputs
	x : in std_logic_vector (17 downto 0);
	y : in std_logic_vector (17 downto 0);
	x0 : in std_logic_vector (17 downto 0);
	y0 : in std_logic_vector (17 downto 0);
	-- outputs
	x_out : out std_logic_vector (17 downto 0);
	y_out : out std_logic_vector (17 downto 0);
	ov : out std_logic);
end mandelbrot_iteration;

architecture Behavioral of mandelbrot_iteration is

	component multiplier	port (
		clk: in std_logic;
		ar: in std_logic_vector(17 downto 0);
		ai: in std_logic_vector(17 downto 0);
		br: in std_logic_vector(17 downto 0);
		bi: in std_logic_vector(17 downto 0);
		pr: out std_logic_vector(17 downto 0);
		pi: out std_logic_vector(17 downto 0));
	end component;
	
	signal px : std_logic_vector (17 downto 0);
	signal py : std_logic_vector (17 downto 0);
	signal sumx : std_logic_vector (17 downto 0);
	signal sumy : std_logic_vector (17 downto 0);
	
	constant escape : std_logic_vector(17 downto 0) := "11"& x"0000";	

begin
	
	mul1 : multiplier port map (
		clk => clk,
		ar => x,	 
		ai => y,
		br => x,  
		bi => y,
		pr => px, 
		pi => py
	);
	
	
	sumx <= px + x0;
	sumy <= py + y0;
	
	x_out <= sumx;
	y_out <= sumy;
	ov <= '1' when (sumx > escape) or (sumy > escape) else '0';
	
end Behavioral;

