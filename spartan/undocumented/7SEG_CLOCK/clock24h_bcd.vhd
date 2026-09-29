----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:36:47 02/19/2016 
-- Design Name: 
-- Module Name:    clock24h_bcd - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity clock24h_bcd is
    Port ( clk_1ms : in  STD_LOGIC;
           hour_bcd : out  STD_LOGIC_VECTOR (7 downto 0);
           minute_bcd : out  STD_LOGIC_VECTOR (7 downto 0);
			  clk_1s : out STD_LOGIC);
end clock24h_bcd;

architecture Behavioral of clock24h_bcd is
	signal half_Sec : STD_LOGIC := '0';
	signal mili : STD_LOGIC_VECTOR (8 downto 0) := (others =>'0');
	signal sec : STD_LOGIC_VECTOR (5 downto 0) := (others =>'0');
	signal min_uni : STD_LOGIC_VECTOR (3 downto 0) := (others =>'0');
	signal min_dec : STD_LOGIC_VECTOR (3 downto 0) := (others =>'0');
	signal hour_uni : STD_LOGIC_VECTOR (3 downto 0) := (others =>'0');
	signal hour_dec : STD_LOGIC_VECTOR (3 downto 0) := (others =>'0');
begin
	clk_1s <= half_sec;
	minute_bcd <= min_dec & min_uni;
	hour_bcd <=  hour_dec & hour_uni;
	
	mili_process: process(clk_1ms) begin
		if rising_edge(clk_1ms) then
			if mili = 500-1 then
				mili <= (others =>'0');
				half_sec <= not half_sec;
			else
				mili <=  mili +1;
			end if;			
		end if;
	end process;
	
	sec_process: process(half_sec) begin
		if rising_edge(half_sec) then
			if sec = 59 then
				sec <= (others =>'0');
				if min_uni = 9 then
					min_uni <= (others =>'0');
					if min_dec = 5 then
						min_dec <= (others =>'0');
						if hour_uni = 9 OR (hour_dec = 2 AND hour_uni = 3) then
							hour_uni <= (others =>'0');
							if hour_dec = 2 then
								hour_dec <= (others =>'0');
							else
								hour_dec <= hour_dec +1;
							end if;					
						else
							hour_uni <= hour_uni +1;
						end if;
					else
						min_dec <= min_dec +1;
					end if;					
				else
					min_uni <= min_uni +1;
				end if;
			else
				sec <=  sec +1;
			end if;
		end if;
	end process;
	
	

end Behavioral;

