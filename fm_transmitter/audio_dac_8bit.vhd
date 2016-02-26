library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity audio_dac_8bit is
    Port ( clk : in  STD_LOGIC;
           data : in  signed (8 downto 0);
           pulseStream : out  STD_LOGIC);
end audio_dac_8bit;

architecture Behavioral of audio_dac_8bit is
	signal sum : unsigned (9 downto 0) := to_unsigned(0,10);
	signal unsigned_data : unsigned (8 downto 0);
begin
	pulseStream <= sum(9);
	
	process (clk) begin
		if rising_edge(clk) then
			unsigned_data <= unsigned(data xor "100000000"); -- xor operation transform the 2 complement representation in offset binary
			sum <= unsigned("0" & sum(8 downto 0)) + unsigned_data; 
		end if;
	end process;

end Behavioral;
 