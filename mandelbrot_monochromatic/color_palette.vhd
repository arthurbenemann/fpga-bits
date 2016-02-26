
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity color_palette is Port ( 
	clk : in std_logic;
	color : in  STD_LOGIC_VECTOR (19 downto 0);
   color_rgb : out  STD_LOGIC_VECTOR (11 downto 0));
end color_palette;


architecture Behavioral of color_palette is
 signal color_buff : unsigned (1 downto 0) :=(others=>'0');
 signal temp : natural := 0;
 
	function count_ones(s : std_logic_vector) return integer is
	  variable temp : natural := 0;
	begin
	  for i in s'range loop
		 if s(i) = '1' then temp := temp + 1; 
		 end if;
	  end loop;
	  return temp;
	end function count_ones;

begin

--	color_rgb <= color_buff; -- monochromatic mapping
	with color_buff select color_rgb <= -- rgb palette
		x"00f" when "00",
		x"0f0" when "01",
		x"f00" when "10",
		x"fff" when "11",
		x"000" when others;
		
	process (clk) begin
		if rising_edge(clk) then
			color_buff <= to_unsigned(count_ones(color),2);
		end if;
	end process;	

end Behavioral;

