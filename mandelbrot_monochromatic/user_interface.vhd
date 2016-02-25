library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity user_interface is port(
	clk,DIR_UP,DIR_DOWN,DIR_LEFT,DIR_RIGHT : in  std_logic;
	x_offset,y_offset : out std_logic_vector(8 downto 0)); 
end user_interface;

architecture Behavioral of user_interface is

	signal x,y : signed(8 downto 0) :=(others=>'0'); 

	signal counter : unsigned(17 downto 0) := to_unsigned(0,18);
begin

	x_offset <= std_logic_vector(x);
	y_offset <= std_logic_vector(y);
	
	panning : process (clk) begin
		if rising_edge(clk) then
			counter <= counter +1;
			if counter = 0 then
				if DIR_LEFT = '1' then
					x <= x + 1;
				end if;
				if DIR_RIGHT = '1' then
					x <= x - 1;
				end if;
				if DIR_UP = '1' then
					y <= y + 1;
				end if;
				if DIR_DOWN = '1' then
					y <= y - 1;
				end if;
			end if;
		end if;
	end process;	
	

end Behavioral;

