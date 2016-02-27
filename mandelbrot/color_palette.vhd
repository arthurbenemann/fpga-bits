
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity color_generator is Port ( 
	clk : in std_logic;
	overflow_bits : in  STD_LOGIC_VECTOR (19 downto 0);
   color_rgb : out  STD_LOGIC_VECTOR (11 downto 0));
end color_generator;


architecture Behavioral of color_generator is
 signal count : unsigned (3 downto 0) :=(others=>'0');
 signal overflow_bits_buffer : STD_LOGIC_VECTOR (19 downto 0);
 signal color_rgb_buffer,douta : STD_LOGIC_VECTOR (11 downto 0);
 
	function count_ones(s : std_logic_vector) return integer is
	  variable temp : natural := 0;
	begin
	  for i in s'range loop
		 if s(i) = '1' then temp := temp + 1; 
		 end if;
	  end loop;
	  return temp;
	end function count_ones;
	
	
	COMPONENT color_palette PORT (
		 clka : IN STD_LOGIC;
		 addra : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		 douta : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
	  );
	END COMPONENT;

begin
	
	color_rgb <= color_rgb_buffer;


	rom: color_palette PORT MAP (
		clka => clk,
		addra => std_logic_vector(count),
		douta =>  douta
	 );

			
	process (clk) begin
		if rising_edge(clk) then
			overflow_bits_buffer <= overflow_bits;
			count <= to_unsigned(count_ones(overflow_bits_buffer),4);
			color_rgb_buffer <= douta; 
		end if;
	end process;	

end Behavioral;

