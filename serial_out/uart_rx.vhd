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
	signal sr : std_logic_vector(39 downto 0) := (others => '1');
begin
	
	process (clk) begin
		if rising_edge(clk) then		
			if baud_counter = integer(clock_freq*1000.0/baudrate/4.0 - 1.0) then
				baud_counter <= (others => '0');
				
				sr <= rx & sr(39 downto 1);	-- shift over-sampled data into shift_reg
				
				if((sr(38) and  sr(37)) and	-- stop bit
				   (sr(34) xnor sr(33)) and	-- MSB
				   (sr(30) xnor sr(29)) and
				   (sr(26) xnor sr(25)) and
				   (sr(22) xnor sr(21)) and
				   (sr(18) xnor sr(17)) and
				   (sr(14) xnor sr(13)) and
				   (sr(10) xnor sr(09)) and
				   (sr(06) xnor sr(05)) and	-- LSB
				   (sr(02) nor  sr(01))) = '1' then -- start bit
						rx_data <= sr(34)&sr(30)&sr(26)&sr(22)&sr(18)&sr(14)&sr(10)&sr(6);
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
