library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity topModule is Port ( 
	CLK : in std_logic;
	SW : in  STD_LOGIC_VECTOR (7 downto 0);
   LED : out  STD_LOGIC_VECTOR (7 downto 0);
	GPIO0: out std_logic;
	TX: out std_logic);
end topModule;

architecture Behavioral of topModule is

	component uart port(		
		clk : in  std_logic;
		tx_data : in std_logic_vector(7 downto 0);
		tx_en : in std_logic;
		tx_ready : out std_logic;
		tx  : out std_logic); 
	end component;

	signal counter : std_logic_vector(7 downto 0):= (others=>'0');
	
	signal tx_en : std_logic := '0';
	signal tx_out : std_logic;
	signal tx_data : std_logic_vector(7 downto 0):= (others=>'0');
	
begin

	LED <= SW;
	TX <= tx_out;
	GPIO0 <= tx_out;
	
	uart1 : uart port map(
		clk => CLK,
		tx_data => tx_data,
		tx_en => tx_en,
		tx_ready => open,
		tx => tx_out
	);
	
	
	data : process(clk) begin
		if rising_edge(clk) then
			counter <= counter +1;
			if (counter = x"ff") then
				tx_data <= tx_data +1;
				tx_en <= '1';
			else
				tx_en <= '0';
			end if;
		end if;
	end process;
	
end Behavioral;