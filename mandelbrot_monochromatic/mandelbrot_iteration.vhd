
-- Data is stored in Q+2.15 as the spartan 6 DSP blocks can do 18x18 multiplication

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity mandelbrot_iteration is port(
	clk : in  std_logic;
	-- inputs
	ov_in : in std_logic;
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
		ar: in std_logic_vector(17 downto 0);	-- Q+2.15
		ai: in std_logic_vector(17 downto 0);
		br: in std_logic_vector(17 downto 0);
		bi: in std_logic_vector(17 downto 0);
		pr: out std_logic_vector(21 downto 0); -- Q+6.15
		pi: out std_logic_vector(21 downto 0)); 
	end component;
	
	signal px,py: std_logic_vector (21 downto 0); -- Q+6.15
	signal sumx,sumy : signed (18 downto 0); -- Q+3.15
	
	signal x0_d1, y0_d1 : std_logic_vector (17 downto 0) := (others =>'0');
	
	signal ov_x,ov_y : std_logic;
	
	constant escape : signed (18 downto 0) := to_signed(+2*(2**15),19);  -- Q+3.15
	
begin
	
	mul1 : multiplier port map (	-- latency of 1 clock
		clk => clk,
		ar => x,	 
		ai => y,
		br => x,  
		bi => y,
		pr => px, 
		pi => py
	);
	
	constants_delay :process (clk) begin		-- The constants need to be delayed by one cycle to match the multiplier latency
		if rising_edge(clk) then
			x0_d1 <= x0;
			y0_d1 <= y0;
		end if;
	end process;
	
	
	sumx <= signed(px(18 downto 0)) + signed(x0_d1(17) & x0_d1); -- extended x0 to Q+3.15
	sumy <= signed(py(18 downto 0)) + signed(y0_d1(17) & y0_d1);
	
	x_out <= std_logic_vector(sumx(17 downto 0)); -- constrain to Q+2.15
	y_out <= std_logic_vector(sumy(17 downto 0));
	
	ov_x <=  '1' when sumx > escape else '1' when sumx < -escape else '0';				
	ov_y <=  '1' when sumy > escape else '1' when sumy < -escape else	'0';				
	ov <= ov_x or ov_y or ov_in;
	
end Behavioral;

