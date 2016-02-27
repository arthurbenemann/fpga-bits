library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity topModule is Port ( 
	CLK : in STD_LOGIC;
	GPIO0,AUDIO1_RIGHT,AUDIO1_LEFT : out  STD_LOGIC;
   SEVENSEG_SEG : out std_logic_vector(7 downto 0);
   SEVENSEG_AN : out std_logic_vector(4 downto 0));
end topModule;

architecture Behavioral of topModule is
		
	component pll port (
	  CLK_IN1 : in     std_logic;
	  clk_modulator : out    std_logic;
	  clk_32 : out    std_logic
	 );
	end component;
	
	signal audio_clk : std_logic;
	signal clk_modulator : std_logic;
	signal clk_32 : std_logic;
	
	COMPONENT counter PORT ( -- max count of 236646400
		clk : IN STD_LOGIC;
		q : OUT STD_LOGIC_VECTOR(27 DOWNTO 0));
	END COMPONENT;
	
	signal addr_counter : STD_LOGIC_VECTOR(27 downto 0);
	
	COMPONENT rom_memory	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(8 DOWNTO 0));
	END COMPONENT;
	
	signal douta : STD_LOGIC_VECTOR(8 DOWNTO 0);
	signal audio_data_unsigned : unsigned(8 downto 0);
	signal audio_data_signed : signed(8 downto 0);
	
	COMPONENT audio_dac_8bit PORT(
		clk : IN std_logic;
		data : IN signed(8 downto 0);          
		pulseStream : OUT std_logic
		);
	END COMPONENT;

	signal audio_out : std_logic;
	
	COMPONENT fm_modulator PORT(
		clk, clk_modulator : IN std_logic;
		data : IN signed(8 downto 0);          
		fm_out : OUT std_logic);
	END COMPONENT;
	
	COMPONENT ms_timer PORT(
		clk : IN std_logic;
		clk_1ms : OUT std_logic);
	END COMPONENT;
	
	signal clk_1ms : std_logic;
	
	COMPONENT seven_seg PORT(
		display_hex : IN std_logic_vector(15 downto 0);
		clk : IN std_logic;
		double_dot : IN std_logic;
		anodes : OUT std_logic_vector(4 downto 0);
		sevenseg : OUT std_logic_vector(7 downto 0));
	END COMPONENT;

begin
	
	clock_manager : pll port map (
		CLK_IN1 => CLK,
		clk_modulator => clk_modulator,
		clk_32 => clk_32
	);	
	
	addr_counter1 : counter PORT MAP (
		clk => clk_32,
		q => addr_counter
	);	

	waveform_rom : rom_memory PORT MAP (
		clka => clk_32,
		addra => addr_counter(27 downto 12),
		douta => douta
	);
	
	audio_data_signed <= signed(douta xor "100000000");

	Inst_audio_dac_8bit: audio_dac_8bit PORT MAP(
		clk => clk_32,
		data => audio_data_signed,
		pulseStream => audio_out
	);
	
	AUDIO1_LEFT <= audio_out;
	AUDIO1_RIGHT <= audio_out;

	Inst_fm_modulator: fm_modulator PORT MAP(
		clk => clk_32,
		clk_modulator => clk_modulator,
		data => audio_data_signed,
		fm_out => GPIO0
	);
	
	Inst_ms_timer: ms_timer PORT MAP(
		clk =>  clk_32,
		clk_1ms =>  clk_1ms
	);
	
	Inst_seven_seg: seven_seg PORT MAP(
		display_hex => x"f947",
		clk => clk_1ms,
		double_dot => '0',
		anodes => SEVENSEG_AN,
		sevenseg => SEVENSEG_SEG
	);

end Behavioral;