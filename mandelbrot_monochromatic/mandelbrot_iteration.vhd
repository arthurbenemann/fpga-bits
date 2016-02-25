
-- Data is stored in Q+2.15 as the spartan 6 DSP blocks can do 18x18 multiplication
-- This design has a latency of 7 cycles

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity mandelbrot_iteration is port(
	clk : in  std_logic;
	-- inputs
	ov_in : in std_logic;
	x,y,x0,y0 : in std_logic_vector (17 downto 0);
	-- outputs
	x_out,y_out,x0_out,y0_out : out std_logic_vector (17 downto 0);
	ov : out std_logic);
end mandelbrot_iteration;

architecture Behavioral of mandelbrot_iteration is

	component multiplier	port (
		clk: in std_logic;
		ar,ai,br,bi: in std_logic_vector(17 downto 0);	-- Q+2.15
		pr,pi: out std_logic_vector(21 downto 0)); -- Q+6.15
	end component;
	
	-- local signals
	signal mulx,muly: std_logic_vector(17 downto 0);
	signal px,py: std_logic_vector (21 downto 0); -- Q+6.15
	signal ov_x,ov_y : std_logic;
	constant escape : signed (18 downto 0) := to_signed(+2*(2**15),19);  -- Q+3.15
	
	-- pipeline signals
	signal x_1,x0_1,x0_2,x0_3,x0_4,x0_5,x0_6,x0_7 :std_logic_vector(17 downto 0):=(others =>'0');
	signal y_1,y0_1,y0_2,y0_3,y0_4,y0_5,y0_6,y0_7 :std_logic_vector(17 downto 0):=(others =>'0');
	signal ov_in_1,ov_in_2,ov_in_3,ov_in_4,ov_in_5,ov_in_6,ov_in_7 : std_logic :='0';
	signal sumx_6,sumy_6 : signed (18 downto 0):=(others =>'0'); -- Q+3.15		
	
begin
	
	-- overflow check per channel
	ov_x <=  '1' when sumx_6 > escape else '1' when sumx_6 < -escape else '0';				
	ov_y <=  '1' when sumy_6 > escape else '1' when sumy_6 < -escape else '0';	
	
	mul1 : multiplier port map (	-- latency of 4 clock
		clk => clk,
		ar => mulx,	ai => muly,	br => mulx, bi => muly,
		pr => px, pi => py
	);
	
	processing_pipeline :process (clk) begin
		if rising_edge(clk) then			
			-- cycle 1 - receive
			ov_in_1 <= ov_in;
			x0_1 <= x0;	y0_1 <= y0;
			x_1  <= x; 	y_1  <= y;
			mulx <= x_1; muly <= y_1;
			-- cycle 2 - multiply1
			ov_in_2 <= ov_in_1;
			x0_2 <= x0_1;	y0_2 <= y0_1;
			-- cycle 3 - multiply2
			ov_in_3 <= ov_in_2;
			x0_3 <= x0_2;	y0_3 <= y0_2;
			-- cycle 4 - multiply3
			ov_in_4 <= ov_in_3;
			x0_4 <= x0_3;	y0_4 <= y0_3;
			-- cycle 5 - multiply4
			ov_in_5 <= ov_in_4;
			x0_5 <= x0_4;	y0_5 <= y0_4;	
			-- cycle 6 - sum 
			x0_6<= x0_5;	y0_6 <= y0_5;	
			ov_in_6 <= ov_in_5;			
			sumx_6 <= signed(px(18 downto 0)) + signed(x0_6(17) & x0_6); -- extended x0 to Q+3.15
			sumy_6 <= signed(py(18 downto 0)) + signed(y0_6(17) & y0_6);
			-- cycle 7 - overflow check / output
			x0_7<= x0_6;	y0_7 <= y0_6;	
			ov_in_7 <= ov_in_6;	
			x0_out<= x0_7;y0_out<= y0_7;
			x_out <= std_logic_vector(sumx_6(17 downto 0)); -- constrain to Q+2.15
			y_out <= std_logic_vector(sumy_6(17 downto 0));			
			ov <= ov_x or ov_y or ov_in_7;
		end if;
	end process;
	
end Behavioral;

