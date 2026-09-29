library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity topModule is Port ( 
	CLK : in std_logic;
	GPIO0: out std_logic;
	GPIO1: out std_logic;
	RX: in std_logic;
	TX: out std_logic);
end topModule;

architecture Behavioral of topModule is

	component uart_tx port(		
		clk : in  std_logic;
		tx_data : in std_logic_vector(7 downto 0);
		tx_en : in std_logic;
		tx_ready : out std_logic;
		tx  : out std_logic); 
	end component;
	
	component uart_rx port (
		clk : in std_logic;
		rx :in std_logic;          
		rx_data : out std_logic_vector(7 downto 0);
		rx_ready : out std_logic);
	end component;

	signal counter : std_logic_vector(7 downto 0):= (others=>'0');
	
	signal tx_en : std_logic := '0';
	signal tx_ready : std_logic;
	signal tx_out : std_logic;
	signal tx_data : std_logic_vector(7 downto 0):= (others=>'0');
	signal rx_ready : std_logic;
	signal rx_data : std_logic_vector(7 downto 0);
	
begin
	TX <= tx_out;
	GPIO0 <= RX;
	GPIO1 <= tx_out;
	
	uart1_tx : uart_tx port map(
		clk => CLK,
		tx_data => tx_data,
		tx_en => tx_en,
		tx_ready => tx_ready,
		tx => tx_out
	);
	
	uart1_rx: uart_rx port map(
		clk => CLK,
		rx => RX,
		rx_data => rx_data,
		rx_ready => rx_ready
	);
	
	retransmit : process(clk) begin
		if rising_edge(clk) then
			if (rx_ready and tx_ready) = '1' then
				tx_data <= rx_data + 1;
				tx_en <= '1';
			else
				tx_en <= '0';
			end if;
		end if;
	end process;
	
end Behavioral;