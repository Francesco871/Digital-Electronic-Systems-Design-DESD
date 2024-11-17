library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ShiftRegister_v1 is
	Generic(
		SR_DEPTH : POSITIVE := 4;
		SR_INIT : STD_LOGIC := '0'
	);
	Port (
 		reset : IN STD_LOGIC;
		clk : IN STD_LOGIC;
		din : IN STD_LOGIC;
		shift_enable : IN STD_LOGIC;
		dir : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(SR_DEPTH-1 DOWNTO 0)
	);
end ShiftRegister_v1;

architecture Behavioral of ShiftRegister_v1 is
	signal q : STD_LOGIC_VECTOR (SR_DEPTH-1 DOWNTO 0) := (0 => '1', Others => SR_INIT);
begin

	dout <= q;

	process(clk, reset)
	begin
		if reset = '1' then
			q <= (0 => '1', Others => SR_INIT);
		elsif rising_edge(clk) then
			if shift_enable = '1' then
				if dir = '0' then -- da dx a sx
					q <= q(SR_DEPTH-2 downto 0) & din;
				elsif dir = '1' then -- da sx a dx
					q <= din & q(SR_DEPTH-1 downto 1);
				end if;
			end if;
		end if;
	end process;

end Behavioral;
