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
begin
	pulseStream <= sum(9);
	
	process (clk) begin
		if rising_edge(clk) then
			sum <= ("0" & sum(8 downto 0)) + ("0" & unsigned (data));
		end if;
	end process;

end Behavioral;
 