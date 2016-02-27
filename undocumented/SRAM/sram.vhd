--
-- SRAM controller for Papilio Duo
--
-- based on 'FPGA Prototyping by VHDL Examples: Xilinx Spartan-3 Version' by Pong P. Chu
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sram is port (
	-- interface
	clk : in  std_logic;
	mem : in std_logic;
	rw : in std_logic; -- read '1' / write '0'
	ready : out std_logic;
	addr : in std_logic_vector(20 downto 0);
	din :	in std_logic_vector(7 downto 0);
	dout : out std_logic_vector(7 downto 0);
	
	-- SRAM interface
	SRAM_ADDR : out  std_logic_vector (20 downto 0);
   SRAM_DATA : inout  std_logic_vector (7 downto 0);
   SRAM_CE : out  std_logic;
   SRAM_WE : out  std_logic;
   SRAM_OE : out  std_logic);
end sram;

architecture Behavioral of sram is
	type state_t is (idle, read1, read2, write1, write2);
	signal state : state_t := idle;	
begin

	SRAM_CE <= '0';	-- sram always enabled
	--SRAM_OE <= '1';

	process(clk) begin
		if rising_edge(clk) then
			case state is
				when idle =>
					ready <= '1';
					SRAM_DATA <= "ZZZZZZZZ";
					SRAM_WE <= '1';
					SRAM_OE <= '1';
					if mem = '1' then
						SRAM_ADDR <= addr;
						if rw = '1' then
							state <= read1;
						else
							state <= write1;
							SRAM_DATA <= din;
						end if;
					end if;
				
				when read1 =>
					ready <= '0';
					SRAM_OE <= '0';
					state <= read2;
				when read2 =>
					SRAM_OE <= '0';
					dout <= SRAM_DATA;
					state <= idle;				
					
				when write1 =>
					ready <= '0';
					SRAM_WE <= '0';
					state <= write2;
				when write2 =>
					SRAM_DATA <= din;
					state <= idle;
			end case;
		end if;
	end process;

end Behavioral;

