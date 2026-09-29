library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity topModule is Port ( 
	CLK : in STD_LOGIC;
	AUDIO1_RIGHT : out  STD_LOGIC;
	AUDIO1_LEFT : out  STD_LOGIC);
end topModule;

architecture Behavioral of topModule is
	
	signal count : STD_LOGIC_VECTOR(27 downto 0);
	signal audio_data : STD_LOGIC_VECTOR(8 downto 0);	
	signal audio_out : STD_LOGIC;
	
	COMPONENT counter PORT ( -- max count of 236646400
		clk : IN STD_LOGIC;
		q : OUT STD_LOGIC_VECTOR(27 DOWNTO 0));
	END COMPONENT;
	
	COMPONENT rom_memory	PORT (
		clka : IN STD_LOGIC;
		addra : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		douta : OUT STD_LOGIC_VECTOR(8 DOWNTO 0));
	END COMPONENT;
	
	COMPONENT audio_dac_8bit PORT(
		clk : IN std_logic;
		data : IN std_logic_vector(8 downto 0);          
		pulseStream : OUT std_logic);
	END COMPONENT;

begin

	AUDIO1_RIGHT <= audio_out;
	AUDIO1_LEFT <= audio_out;	

	addr_counter : counter PORT MAP (
		clk => CLK,
		q => count
	);

	waveform_rom : rom_memory
	PORT MAP (
		clka => CLK,
		addra => count(27 downto 12),
		douta => audio_data
	);

	Inst_audio_dac_8bit: audio_dac_8bit PORT MAP(
		clk => CLK,
		data => audio_data,
		pulseStream => audio_out
	);
	
end Behavioral;