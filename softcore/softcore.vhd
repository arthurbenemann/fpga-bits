library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

entity softcore is port ( 
	clk, RX : in  STD_LOGIC;
   TX : out  STD_LOGIC);
end softcore;

architecture Behavioral of softcore is
	component microblaze port(
		Clk, Reset, UART_Rx : IN STD_LOGIC;
		UART_Tx : OUT STD_LOGIC);
	end component;
begin

	core0 : microblaze port map(
    Clk => Clk, Reset => '0',
    UART_Rx => RX, UART_Tx => TX
  );

end Behavioral;

