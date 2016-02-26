library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.MATH_REAL.ALL;

entity fm_modulator is
    Port ( clk : in  STD_LOGIC;
           data : in  signed (8 downto 0);
           fm_out : out  STD_LOGIC);
end fm_modulator;

architecture Behavioral of fm_modulator is
	
	constant input_clk : real := 320.0; -- MHz
	constant accumulator_size : real := 2**32.0;
	constant fm_frequency : real := 94.7; -- MHz	
	
	constant center_freq : signed(31 downto 0) := to_signed(integer(accumulator_size*fm_frequency/input_clk),32);
	
	
	signal phase_shift_data: signed (31 downto 0) := (others => '0');
	signal phase_shift: signed (31 downto 0) := (others => '0');
	signal phase_accumulator : signed (31 downto 0) := (others => '0');

begin

	fm_out <= std_logic(phase_accumulator(31));
		
	process (clk) begin
		if rising_edge(clk) then
			phase_shift_data <= resize(data & "0000",32);
			phase_shift <= center_freq + phase_shift_data;
			phase_accumulator <= phase_accumulator + phase_shift;						
		end if;
	end process;

end Behavioral;
