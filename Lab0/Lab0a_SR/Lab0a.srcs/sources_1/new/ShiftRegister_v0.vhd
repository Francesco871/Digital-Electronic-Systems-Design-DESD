library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ShiftRegister_v0 is
	Port (
 		reset : IN STD_LOGIC;
		clk : IN STD_LOGIC;
		din : IN STD_LOGIC;
		dout : OUT STD_LOGIC
		);
end ShiftRegister_v0;

architecture Behavioral of ShiftRegister_v0 is
	signal q : STD_LOGIC_VECTOR (0 TO 3);
begin

	dout <= q(3);

	process(clk, reset)
	begin
		if reset = '1' then
			--dout <= '0'; azzerro sia q(3) sia dout => mi mette un latch
			q <= (Others => '0');
		elsif rising_edge(clk) then
			-- oppure su una riga: q <= q(2 downto 0) & din;
			ff : for I in 0 to 3 loop
				if I=0 then
					q(I) <= din;
				else
					q(I) <= q(I-1);
				end if;
			end loop;
		end if;
	end process;

end Behavioral;
