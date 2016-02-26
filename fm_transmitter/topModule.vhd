library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity topModule is Port ( 
	CLK : in STD_LOGIC;
	--SW : in std_logic_vector(7 downto 0);
	--LED : out std_logic_vector(7 downto 0);
	GPIO0,AUDIO1_RIGHT,AUDIO1_LEFT : out  STD_LOGIC);
end topModule;

architecture Behavioral of topModule is
		
	component pll port (
	  CLK_IN1 : in     std_logic;
	  modulator_clk : out    std_logic;
	  main_clk : out    std_logic
	 );
	end component;
	
	signal audio_clk : std_logic;
	signal modulator_clk : std_logic;
	signal main_clk : std_logic;
	
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
		clk : IN std_logic;
		data_clk : IN std_logic;
		data : IN std_logic_vector(8 downto 0);          
		fm_out : OUT std_logic);
	END COMPONENT;

begin
	
	clock_manager : pll port map (
		CLK_IN1 => CLK,
		modulator_clk => modulator_clk,
		main_clk => main_clk
	);	
	
	
	addr_counter1 : counter PORT MAP (
		clk => main_clk,
		q => addr_counter
	);	

	waveform_rom : rom_memory PORT MAP (
		clka => main_clk,
		addra => addr_counter(27 downto 12),
		douta => douta
	);
	audio_data_unsigned <= unsigned(douta);
	audio_data_signed <= signed(douta xor "100000000");

	Inst_audio_dac_8bit: audio_dac_8bit PORT MAP(
		clk => main_clk,
		data => audio_data_signed,
		pulseStream => audio_out
	);
	
	AUDIO1_LEFT <= audio_out;
	AUDIO1_RIGHT <= audio_out;

	Inst_fm_modulator: fm_modulator PORT MAP(
		clk => main_clk,
		data_clk => main_clk,
		data => douta,
		fm_out => GPIO0
	);

end Behavioral;