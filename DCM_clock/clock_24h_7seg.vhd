library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clock_24h_7seg is
  Port (
    CLK : in std_logic;
    SEVENSEG_SEG : out std_logic_vector(7 downto 0);
    SEVENSEG_AN : out std_logic_vector(4 downto 0)
  );
end clock_24h_7seg;

architecture Behavioral of clock_24h_7seg is
	signal clk_1ms : std_logic;
   signal clk_1s : std_logic;
   signal display_hex : std_logic_vector (15 downto 0);

	COMPONENT seven_seg
	PORT(
		display_hex : IN std_logic_vector(15 downto 0);
		clk : IN std_logic;
		double_dot : IN std_logic;
		anodes : OUT std_logic_vector(4 downto 0);
		sevenseg : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;

	COMPONENT ms_timer
	PORT(
		clk : IN std_logic;
		clk_1ms : OUT std_logic
		);
	END COMPONENT;

	COMPONENT clock24h_bcd
	PORT(
		clk_1ms : IN std_logic;
		hour_bcd : OUT std_logic_vector(7 downto 0);
		minute_bcd : OUT std_logic_vector(7 downto 0);
		clk_1s : OUT std_logic
		);
	END COMPONENT;

begin
  	Inst_seven_seg: seven_seg PORT MAP(
		display_hex => display_hex,
		clk => clk_1ms,
		double_dot => clk_1s,
		anodes => SEVENSEG_AN,
		sevenseg => SEVENSEG_SEG
	);

	Inst_clock24h_bcd: clock24h_bcd PORT MAP(
		clk_1ms => clk_1ms,
		hour_bcd => display_hex(15 downto 8),
		minute_bcd => display_hex(7 downto 0),
		clk_1s => clk_1s
	);

	Inst_ms_timer: ms_timer PORT MAP(
		clk =>  CLK,
		clk_1ms =>  clk_1ms
	);
end Behavioral;
