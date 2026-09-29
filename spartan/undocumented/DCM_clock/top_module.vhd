library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Switches_LEDs is
  Port (
    CLK : in std_logic;
    SW : in std_logic_vector(7 downto 0);
    LED : out std_logic_vector(7 downto 0);
    SEVENSEG_SEG : out std_logic_vector(7 downto 0);
    SEVENSEG_AN : out std_logic_vector(4 downto 0)
  );
end Switches_LEDs;


architecture Behavioral of Switches_LEDs is
	COMPONENT clock_24h_7seg PORT(
		CLK : IN std_logic;          
		SEVENSEG_SEG : OUT std_logic_vector(7 downto 0);
		SEVENSEG_AN : OUT std_logic_vector(4 downto 0)
		);
	END COMPONENT;
	
	component my_dcm port (
	  CLK_IN1           : in     std_logic;
	  CLK_OUT1          : out    std_logic
	 );
	end component;
	
	signal CLK_PLL : STD_LOGIC;
begin

	LED <= SW;

	clock_manager : my_dcm port map (
		CLK_IN1 => CLK,
		CLK_OUT1 => CLK_PLL
	);

	Inst_clock_24h_7seg: clock_24h_7seg PORT MAP(
		CLK => CLK_PLL,
		SEVENSEG_SEG => SEVENSEG_SEG,
		SEVENSEG_AN => SEVENSEG_AN
	);

end Behavioral;
