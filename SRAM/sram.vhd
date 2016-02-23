
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sram is port (
	-- interface
	clk : in  STD_LOGIC;
	wea : in std_logic;
	addr : in std_logic_vector(20 downto 0);
	din :	in std_logic_vector(7 downto 0);
	dout : out std_logic_vector(7 downto 0);
	
	-- SRAM interface
	SRAM_ADDR : out  std_logic_vector (20 downto 0);
   SRAM_DATA : inout  std_logic_vector (7 downto 0);
   SRAM_CE : out  std_logic;
   SRAM_WE : out  std_logic;
   SRAM_OE : out  std_logic);
end sram;

architecture Behavioral of sram is
	type state_t is (idle, data_read, data_write);
	signal state : state_t := idle;	
begin

	SRAM_ADDR <= addr;
	SRAM_CE <= '1';
	SRAM_OE <= '1';

	process(clk) begin
		if rising_edge(clk) then
			case state is
				when data_read =>
					SRAM_WE <= '0';
					dout <= SRAM_DATA;
				when data_write =>
					SRAM_WE <= '1';
					SRAM_DATA <= din;
				when others =>
					SRAM_DATA <= "ZZZZZZZZ";
			end case;
		end if;
	end process;

end Behavioral;

