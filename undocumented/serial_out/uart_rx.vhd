library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_rx is Port (
	clk : in  std_logic;
	rx  : in std_logic;
	rx_data : out std_logic_vector(7 downto 0)  := (others => '0');
	rx_ready : out std_logic := '0'); 
end uart_rx;

architecture Behavioral of uart_rx is
	constant clock_freq : real := 32.0; -- Mhz
	constant baudrate : real := 115.2; -- kbits/s
	
	signal baud_counter : std_logic_vector(6 downto 0) := (others => '0');	
	signal sr : std_logic_vector(38 downto 0) := (others => '1');
begin
	
	process (clk) begin
		if rising_edge(clk) then		
			if baud_counter = integer(clock_freq*1000.0/baudrate/4.0 - 1.0) then
				baud_counter <= (others => '0');
				
				sr <= rx & sr(38 downto 1);	-- shift over-sampled data into shift_reg
				
				if((sr(37) and  sr(36)) and	-- stop bit
				   (sr(33) xnor sr(32)) and	-- MSB
				   (sr(29) xnor sr(28)) and
				   (sr(25) xnor sr(24)) and
				   (sr(21) xnor sr(20)) and
				   (sr(17) xnor sr(16)) and
				   (sr(13) xnor sr(12)) and
				   (sr(09) xnor sr(08)) and
				   (sr(05) xnor sr(04)) and	-- LSB
				   (sr(01) nor  sr(00))) = '1' then -- start bit
						rx_data <= sr(33)&sr(28)&sr(24)&sr(20)&sr(16)&sr(12)&sr(8)&sr(4);
						rx_ready <= '1';
						sr <= (others => '1');
				else
						rx_ready <= '0';
				end if;				
			else
				baud_counter <= baud_counter+1;
			end if;			
		end if;	end process;

end Behavioral;
