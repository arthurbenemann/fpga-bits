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
	
	constant input_clk : real := 320.0; -- MHz
	constant accumulator_size : real := 2**32.0;
	constant fm_frequency : real := 94.7; -- MHz	
	
	constant center_freq : signed(31 downto 0) := to_signed(integer(accumulator_size*fm_frequency/input_clk),32);
	
	component phase_adder port (
		a,b : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		s : OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
	end component;
	
	
	signal ph_shift_data,ph_shift,ph_accumulator: signed (31 downto 0) := (others => '0');
	signal sum : std_logic_vector (31 downto 0);

begin
	
	process (clk) begin
		if rising_edge(clk) then
			ph_shift_data <= resize(data & "0000",32);
			ph_shift <= center_freq + ph_shift_data;				
		end if;
	end process;
	
	fast_adder : phase_adder port map (  -- the adder IP is required to run this sum at 320MHz
		a => std_logic_vector(ph_accumulator), b => std_logic_vector(ph_shift),
		s => sum
  );
	
	process (clk_modulator) begin
		if rising_edge(clk_modulator) then
			ph_accumulator <= signed(sum);						
		end if;
	end process;
	
	fm_out <= std_logic(ph_accumulator(31));

end Behavioral;
