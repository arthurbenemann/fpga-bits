library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_tx is Port (
	clk : in  std_logic;
	tx_data : in std_logic_vector(7 downto 0);
	tx_en : in std_logic;
	tx_ready : out std_logic;
	tx  : out std_logic); 
end uart_tx;

architecture Behavioral of uart_tx is
	constant clock_freq : real := 32.0; -- Mhz
	constant baudrate : real := 115.2; -- kbits/s
	
	signal tx_state : std_logic := '1';

	signal tx_shiftreg : std_logic_vector(9 downto 0) := (others => '1');
	signal baud_counter : std_logic_vector(8 downto 0) := (others => '0');	
begin

	tx <= tx_shiftreg(0);
	
	tx_ready <= tx_state;
	
	process (clk) begin
		if rising_edge(clk) then
		
			case tx_state is
				when '1' =>
					baud_counter <= (others => '0');
					
					if tx_en = '1' then
						tx_shiftreg <= '1' & tx_data & '0'; -- stop & data & start					
						tx_state <= '0';
					else
						tx_shiftreg <= (others => '1');
					end if;
					
				when '0'=>					
					if baud_counter = integer(clock_freq*1000.0/baudrate - 1.0) then
						baud_counter <= (others => '0');
						
						if tx_shiftreg = "0000000001" then
							tx_state <= '1';
						else
							tx_shiftreg <= '0' & tx_shiftreg(9 downto 1);
						end if;						
					else
						baud_counter <= baud_counter+1;
					end if;
				when others =>
						tx_state <= '1';
			end case;
			
		end if;	end process;

end Behavioral;
