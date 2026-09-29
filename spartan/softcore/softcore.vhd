library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

entity softcore is port ( 
	clk, RX : in  STD_LOGIC;
   TX : out  STD_LOGIC;
   SW : in std_logic_vector(7 downto 0);
	LED : out  STD_LOGIC_VECTOR (7 downto 0));
end softcore;

architecture Behavioral of softcore is
	component microblaze port(
		Clk, Reset, UART_Rx : IN STD_LOGIC;
		UART_Tx : OUT STD_LOGIC;
		GPO1 : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		GPI1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		GPI1_Interrupt : OUT STD_LOGIC);
	end component;
begin

	core0 : microblaze port map(
    Clk => Clk, Reset => '0',
    UART_Rx => RX, UART_Tx => TX,
    GPO1 => LED,
    GPI1 => SW,
    GPI1_Interrupt => open
  );

end Behavioral;

