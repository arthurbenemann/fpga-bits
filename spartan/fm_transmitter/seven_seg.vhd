library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seven_seg is
    Port ( display_hex : in  STD_LOGIC_VECTOR (15 downto 0);
           clk : in  STD_LOGIC;
			  double_dot : IN STD_LOGIC;
           anodes : out  STD_LOGIC_VECTOR (4 downto 0);
           sevenseg : out  STD_LOGIC_VECTOR (7 downto 0));
end seven_seg;

architecture Behavioral of seven_seg is
	signal value : STD_LOGIC_VECTOR(4 downto 0) := (OTHERS =>'0');
	signal anodes_buf : STD_LOGIC_VECTOR(4 downto 0);
begin 
	anodes <= anodes_buf;

	display_update:process(clk) begin
		if rising_edge(clk) then
			CASE anodes_buf IS
				WHEN "01111" =>
					anodes_buf <= "10111";
					value <= "0" & display_hex(3 downto 0);
				WHEN "10111" =>
					anodes_buf <= "11011";
					value <= "0" & display_hex(7 downto 4);
				WHEN "11011" =>
					anodes_buf <= "11101";
					value <= "0" & display_hex(11 downto 8); 
				WHEN "11101" =>
					anodes_buf <= "11110";
					value <= "0" & display_hex(15 downto 12); 
				WHEN OTHERS =>
					anodes_buf <= "01111";
					value <= "10000";
			END CASE;
		end if;
	end process;
 
  display_mapping:process(value, double_dot) begin
	  CASE value IS
	  WHEN "0" & x"0" => sevenseg <= NOT x"3F"; -- 0
	  WHEN "0" & x"1" => sevenseg <= NOT x"06"; -- 1
	  WHEN "0" & x"2" => sevenseg <= NOT x"5B"; -- 2
	  WHEN "0" & x"3" => sevenseg <= NOT x"4F"; -- 3
	  WHEN "0" & x"4" => sevenseg <= NOT (x"66"or x"80"); -- 4
	  WHEN "0" & x"5" => sevenseg <= NOT x"6D"; -- 5
	  WHEN "0" & x"6" => sevenseg <= NOT x"7D"; -- 6
	  WHEN "0" & x"7" => sevenseg <= NOT x"07"; -- 7
	  WHEN "0" & x"8" => sevenseg <= NOT x"7F"; -- 8
	  WHEN "0" & x"9" => sevenseg <= NOT x"6F"; -- 9
	  WHEN "0" & x"a" => sevenseg <= NOT x"77"; -- A
	  WHEN "0" & x"b" => sevenseg <= NOT x"7C"; -- b
	  WHEN "0" & x"c" => sevenseg <= NOT x"39"; -- C
	  WHEN "0" & x"d" => sevenseg <= NOT x"5E"; -- d
	  WHEN "0" & x"e" => sevenseg <= NOT x"79"; -- E
	  WHEN "0" & x"f" => sevenseg <= NOT x"71"; -- F
	  WHEN OTHERS => sevenseg <= "1111111" & ( NOT double_dot);
	  END CASE;
  end process;

end Behavioral;

