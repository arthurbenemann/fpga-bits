
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity color_palette is Port ( 
	clk : in std_logic;
	color : in  STD_LOGIC_VECTOR (3 downto 0);
   color_rgb : out  STD_LOGIC_VECTOR (11 downto 0));
end color_palette;

architecture Behavioral of color_palette is
 signal color_buff : STD_LOGIC_VECTOR (3 downto 0) :=(others=>'0');
begin

	--color_rgb <= color & color & color; -- monochromatic mapping
	with color_buff select color_rgb <= -- rgb palette
		x"00f" when "1000",
		x"0f0" when "1100",
		x"f00" when "1110",
		x"fff" when "1111",
		x"000" when others;
		
	process (clk) begin
		if rising_edge(clk) then
			color_buff <= color;
		end if;
	end process;	

end Behavioral;

