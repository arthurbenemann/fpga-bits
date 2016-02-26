library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pixel_gen is port ( 
	clk : in  std_logic;
	x0,y0 : in std_logic_vector(17 downto 0);
	color : out std_logic_vector(19 downto 0));
end pixel_gen;

architecture Behavioral of pixel_gen is

	type pipe_state is (s1,s2,s3);
	signal state : pipe_state := s1;
	
	component mandelbrot_pipeline4 port(
		clk : IN  std_logic;
		ov_in : in std_logic; 
		x,y,x0,y0 : IN std_logic_vector(17 downto 0);   
		x_out,y_out,x0_out,y0_out : OUT std_logic_vector(17 downto 0);
		ov : out std_logic_vector (3 downto 0));
	end component;
	
	signal x_in,y_in,x0_in,y0_in : std_logic_vector(17 downto 0);
	signal x_out,y_out,x0_out,y0_out : std_logic_vector(17 downto 0);
	signal ov_in : std_logic;
	signal ov_out : std_logic_vector (3 downto 0);
	
	-- latches
	signal x_out1, y_out1, x0_out1, y0_out1 : std_logic_vector(17 downto 0);
	signal x_out2, y_out2, x0_out2, y0_out2 : std_logic_vector(17 downto 0);
	signal x_out3, y_out3, x0_out3, y0_out3 : std_logic_vector(17 downto 0);
	signal x_out4, y_out4, x0_out4, y0_out4 : std_logic_vector(17 downto 0);
	signal ov1, ov2, ov3, ov4 : std_logic_vector (3 downto 0);
	signal overflow : std_logic_vector (19 downto 0);
	
	
begin

	color <= not (overflow);

	pipeline : mandelbrot_pipeline4 port map(
		clk => clk,
		ov_in => ov_in,
		x => x_in, y => y_in, x0 => x0_in, y0 => y0_in,     -- inputs
		x_out => x_out, y_out => y_out, ov => ov_out, -- outputs
		x0_out=> x0_out, y0_out => y0_out
	);

	piped : process (clk) begin
		if rising_edge(clk) then	
			case state is
				when s1 =>
					x_in <= x0; y_in <= y0; x0_in <= x0; y0_in <= y0; ov_in <= '0';
					x_out1 <= x_out; y_out1 <= y_out; x0_out1 <= x0_out; y0_out1 <= y0_out;
					ov1 <= ov_out;
					state <= s2;					
				when s2 =>
					x_in  <= x_out1; y_in <= y_out1; x0_in <= x0_out1; y0_in <= y0_out1; ov_in <= ov1(0);
					         x_out2<= x_out; y_out2 <= y_out; x0_out2 <= x0_out;y0_out2 <= y0_out;
					ov2 <= ov_out;
					state <= s3;																		
				when s3 =>
					x_in  <= x_out2; y_in <= y_out2; x0_in <= x0_out2; y0_in <= y0_out2; ov_in <= ov2(0);
					overflow <= ov1 & ov2 & ov_out & x"00";
					state <= s1;
			end case;			
		end if;
	end process;
end Behavioral;

