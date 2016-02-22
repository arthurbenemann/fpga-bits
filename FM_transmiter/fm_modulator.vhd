library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity fm_modulator is
    Port ( clk : in  STD_LOGIC;
	        data_clk : in  STD_LOGIC;
           data : in  STD_LOGIC_VECTOR (8 downto 0);
           fm_out : out  STD_LOGIC);
end fm_modulator;

architecture Behavioral of fm_modulator is
	signal phase_accumulator : std_logic_vector (31 downto 0) := (others => '0');
	--signal phase_shift: std_logic_vector (31 downto 0) := (others => '0');
	
	constant input_clk : real := 256.0; -- MHz
	constant accumulator_size : real := 2**32.0;
	constant fm_frequency : real := 94.7; -- MHz
	
	
	
   signal shift_ctr         : std_logic_vector (4 downto 0) := (others => '0');
   signal beep_counter      : std_logic_vector (19 downto 0):= (others => '0'); -- gives a 305Hz beep signal
   signal message           : std_logic_vector(33 downto 0) := "1010100011101110111000101010000000";	

		
	
begin

	fm_out <= std_logic(phase_accumulator(31));
	
--	audio_buffer : process (data_clk) begin
--		if rising_edge(data_clk) then
--			phase_shift <= integer(accumulator_size*fm_frequency/input_clk) + ( x"00" &"000" & data & x"000") - x"100000"; --  max modulation shift should be 1258291
--			phase_shift <=   integer(accumulator_size*fm_frequency/input_clk) + (x"00000" & "000" & data); 
--		end if;
--	end process;
	
	process (clk) begin
		if rising_edge(clk) then	
			--phase_accumulator <= phase_accumulator + phase_shift;			
			
						
				if beep_counter = x"FFFFF" then
					if shift_ctr = "00000" then
						message <= message(0) & message(33 downto 1);
					end if;
					shift_ctr <= shift_ctr + 1;
				end if;      
				
				-- The constants are calculated as (desired freq)/320Mhz*2^32
				if message(0) = '1' then
					if beep_counter(19) = '1' then
						phase_accumulator <= phase_accumulator + integer(accumulator_size*fm_frequency/input_clk) + 1006633; 
					else
						phase_accumulator <= phase_accumulator + integer(accumulator_size*fm_frequency/input_clk) - 1006633; 
					end if;
				else 
					phase_accumulator <= phase_accumulator + integer(accumulator_size*fm_frequency/input_clk); -- gives 94700kHz signal
				end if;
				
				beep_counter <= beep_counter+1;
			
		end if;
	end process;

end Behavioral;
