library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity audio_dac_8bit is
    Port ( clk : in  STD_LOGIC;
           data : in  STD_LOGIC_VECTOR (8 downto 0);
           pulseStream : out  STD_LOGIC);
end audio_dac_8bit;

architecture Behavioral of audio_dac_8bit is
	signal sum : STD_LOGIC_VECTOR (9 downto 0) := (others =>'0');
begin
	pulseStream <= sum(9);
	
	process (clk) begin
		if rising_edge(clk) then
			sum <= ("0" & sum(8 downto 0)) + ("0" &data);
		end if;
	end process;

end Behavioral;
