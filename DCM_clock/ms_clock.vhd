library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ms_timer is
    Port ( clk : in  STD_LOGIC;
           clk_1ms : out  STD_LOGIC);
end ms_timer;

architecture Behavioral of ms_timer is
  signal counter : STD_LOGIC_VECTOR(21 downto 0) := (others =>'0');
begin

	clk_process: process(clk)
	begin
		if rising_edge(clk) then
			if counter = ((32000000/1000)-1) then
				counter <= (others =>'0');
				clk_1ms <= '1';
			else
				counter <= counter +1;
				clk_1ms <= '0';
			end if;
		end if;
	end process;

end Behavioral;