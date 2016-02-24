
-- Data is stored in Q+2.15 as the spartan 6 DSP blocks can do 18x18 multiplication

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
		ar: in std_logic_vector(17 downto 0);	-- Q+2.15
		ai: in std_logic_vector(17 downto 0);
		br: in std_logic_vector(17 downto 0);
		bi: in std_logic_vector(17 downto 0);
		pr: out std_logic_vector(21 downto 0); -- Q+6.15
		pi: out std_logic_vector(21 downto 0)); 
	end component;
	
	signal px,py: std_logic_vector (21 downto 0); -- Q+6.15
	signal sumx,sumy : std_logic_vector (18 downto 0); -- Q+3.15
	
	signal x0_d1, y0_d1 : std_logic_vector (17 downto 0) := (others =>'0');
	
	signal ov_x,ov_y : std_logic;
	
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
	
	
	sumx <= px(18 downto 0) + (x0_d1(17) & x0_d1); -- extended x0 to Q+3.15
	sumy <= py(18 downto 0) + (y0_d1(17) & y0_d1);
	
	x_out <= sumx(17 downto 0); -- constrain to Q+2.15
	y_out <= sumy(17 downto 0);
	
	ov_x <=  '0' when sumx(18 downto 15) = "0010" else
				'0' when sumx(18 downto 15) = "0001" else
				'0' when sumx(18 downto 15) = "0000" else
				'0' when sumx(18 downto 15) = "1111" else
				'0' when sumx(18 downto 15) = "1110" else
				'1';
				
	ov_y <=  '0' when sumy(18 downto 15) = "0010" else
				'0' when sumy(18 downto 15) = "0001" else
				'0' when sumy(18 downto 15) = "0000" else
				'0' when sumy(18 downto 15) = "1111" else
				'0' when sumy(18 downto 15) = "1110" else
				'1';
	ov <= ov_x or ov_y;
end Behavioral;

