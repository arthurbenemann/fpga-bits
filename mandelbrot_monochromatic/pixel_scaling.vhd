library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity pixel_scaling is port(
	x_pixel : in  std_logic_vector (10 downto 0);
   y_pixel : in  std_logic_vector (9 downto 0);
   x0 : out  std_logic_vector (17 downto 0); -- Q+2.15
   y0 : out  std_logic_vector (17 downto 0));
end pixel_scaling;

architecture Behavioral of pixel_scaling is

begin

	x0 <= std_logic_vector(signed(x_pixel)-600)& "0000000"; 
	y0 <= std_logic_vector(signed(y_pixel)-300)& "00000000"; 

end Behavioral;

