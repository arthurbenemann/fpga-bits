library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.MATH_REAL.ALL;

entity fm_modulator is Port ( 
	clk, clk_modulator : in  STD_LOGIC;
   data : in  signed (8 downto 0);
   fm_out : out  STD_LOGIC);
end fm_modulator;

architecture Behavioral of fm_modulator is
	
	constant input_clk : real := 256.0; -- MHz
	constant accumulator_size : real := 2**32.0;
	constant fm_frequency : real := 94.7; -- MHz	
	
	constant center_freq : signed(31 downto 0) := to_signed(integer(accumulator_size*fm_frequency/input_clk),32);
	
	component phase_adder port (
		clk: in std_logic;
		a,b : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		s : OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
	end component;
	
	
	signal ph_shift_data,ph_shift: signed (31 downto 0);
	signal sum : std_logic_vector (31 downto 0);

begin
	
	process (clk) begin
		if rising_edge(clk) then
			ph_shift_data <= resize(data & x"000",32);	 -- right shift data 12 times so the full range is about +-10000000, which should equal a freq. dev. of +-75kHz
			ph_shift <= center_freq + ph_shift_data;				
		end if;
	end process;
	
	fast_adder : phase_adder port map (  -- the adder IP is required to run this sum at 320MHz
		clk => clk_modulator,
		a => std_logic_vector(ph_shift), b => sum,
		s => sum
  );	
	
	fm_out <= sum(31);

end Behavioral;
