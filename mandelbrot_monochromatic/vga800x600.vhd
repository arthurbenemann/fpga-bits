
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga800x600 is Port ( 
	clk : in  std_logic; -- 40 MHz
	red : out std_logic_vector(3 downto 0);
	green : out std_logic_vector(3 downto 0);
	blue : out std_logic_vector(3 downto 0);
	hsync: out std_logic;
	vsync: out std_logic);
end vga800x600;

architecture Behavioral of vga800x600 is

	signal hcount : std_logic_vector(10 downto 0) := (others =>'0');
	signal vcount : std_logic_vector(9 downto 0) := (others =>'0');
	
begin

	counters : process(clk) begin
		if rising_edge(clk) then
			-- Counters
			if hcount = 1055 then
				hcount <= (others =>'0');
				if vcount = 627 then
					vcount <= (others =>'0');
				else
					vcount <= vcount + 1;
				end if;
			else
				hcount <= hcount + 1;
			end if;
			
			-- Hsync
			if hcount >= (800+40) and hcount < (800+40+128) then
				hsync <= '0';
			else
				hsync <= '1';
			end if;			
			
			-- Vsync
			if vcount >= (600+1) and vcount < (600+1+4) then
				vsync <= '0';
			else
				vsync <= '1';
			end if;
			
			-- Colors
			if hcount < 800 and vcount < 600 then
				red <= hcount(3 downto 0);
				green <= "0000";
				blue <= vcount(3 downto 0);
			else
				red <= "0000";
				green <= "0000";
				blue <= "0000";
			end if;
			
		end if;
	end process;
	
end Behavioral;

