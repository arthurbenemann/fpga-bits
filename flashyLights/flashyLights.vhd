library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity flashyLights is
    Port ( CLK : in  STD_LOGIC;
           LED : out  STD_LOGIC_VECTOR (7 downto 0));
end flashyLights;

architecture Behavioral of flashyLights is
	
	COMPONENT counter30 PORT (
		clk : IN STD_LOGIC;
		q : OUT STD_LOGIC_VECTOR(29 DOWNTO 0));
	END COMPONENT;
	
	COMPONENT memmory	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
	END COMPONENT;
	
	signal count : STD_LOGIC_VECTOR(29 downto 0);
begin

	addr_counter : counter30 PORT MAP (
		clk => CLK,
		q => count
	);

	rom_memory : memmory
	PORT MAP (
		clka => CLK,
		addra => count(29 downto 20),
		douta => LED
	);
	
end Behavioral;

