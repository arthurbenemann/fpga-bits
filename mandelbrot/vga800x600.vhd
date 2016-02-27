
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga800x600 is Port ( 
	clk : in  std_logic; -- 40 MHz
	-- input
	color : in std_logic_vector(11 downto 0);
	
	-- logical interface
	h : out std_logic_vector(10 downto 0);
	v : out std_logic_vector(9 downto 0);
	
	-- physical interface
	red : out std_logic_vector(3 downto 0);
	green : out std_logic_vector(3 downto 0);
	blue : out std_logic_vector(3 downto 0);
	hsync: out std_logic;
	vsync: out std_logic);
end vga800x600;

architecture Behavioral of vga800x600 is

	signal hcount : std_logic_vector(10 downto 0) := (others =>'0');
	signal vcount : std_logic_vector(9 downto 0) := (others =>'0');
	
	-- SVGA timing 800x600@60Hz pixel freq 40Mhz - http://tinyvga.com/vga-timing/800x600@60Hz
	constant h_visible	: integer := 800;
	constant h_front 		: integer := 40;
	constant h_sync 		: integer := 128;
	constant h_total		: integer := 1056;
	constant v_visible	: integer := 600;
	constant v_front 		: integer := 1;
	constant v_sync 		: integer := 4;
	constant v_total		: integer := 628;	
	
	constant pipeline_delay : integer := 12;
	
begin
	h <= hcount;
	v <= vcount;

	counters : process(clk) begin
		if rising_edge(clk) then
			-- Counters
			if hcount = (h_total-1) then
				hcount <= (others =>'0');
				if vcount = (v_total-1) then
					vcount <= (others =>'0');
				else
					vcount <= vcount + 1;
				end if;
			else
				hcount <= hcount + 1;
			end if;
			
			-- Hsync
			if hcount >= (h_visible+h_front+ pipeline_delay) and hcount < (h_visible+h_front+h_sync + pipeline_delay) then
				hsync <= '0';
			else
				hsync <= '1';
			end if;			
			
			-- Vsync
			if vcount >= (v_visible+v_front+ pipeline_delay) and vcount < (v_visible+v_front+v_sync + pipeline_delay) then
				vsync <= '0';
			else
				vsync <= '1';
			end if;
			
			-- Colors
			if hcount < h_visible and vcount < v_visible then
				red   <= color(11 downto 8);
				green <= color( 7 downto 4);
				blue  <= color( 3 downto 0);
			else
				red <= "0000";
				green <= "0000";
				blue <= "0000";
			end if;
			
		end if;
	end process;
	
end Behavioral;

