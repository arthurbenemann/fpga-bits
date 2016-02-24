library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity pixel_scaling is port(
	x_pixel : in  std_logic_vector (10 downto 0);
   y_pixel : in  std_logic_vector (9 downto 0);
   x0 : out  std_logic_vector (17 downto 0);
   y0 : out  std_logic_vector (17 downto 0));
end pixel_scaling;

architecture Behavioral of pixel_scaling is

begin

	x0 <= x_pixel & x_pixel(6 downto 0); 
	y0 <= y_pixel & y_pixel(7 downto 0);

end Behavioral;

