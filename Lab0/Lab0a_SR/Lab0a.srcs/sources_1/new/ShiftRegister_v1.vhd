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
		dout : OUT STD_LOGIC
	);
end ShiftRegister_v1;

architecture Behavioral of ShiftRegister_v1 is
	signal q : STD_LOGIC_VECTOR (0 TO SR_DEPTH-1) := (Others => SR_INIT);
begin

	dout <= q(SR_DEPTH-1);

	process(clk, reset)
	begin
		if reset = '1' then
			q <= (Others => SR_INIT);
		elsif rising_edge(clk) then
			-- oppure su una riga: q <= din & q(0 TO SR_DEPTH-2)
			ff : for I in 0 to SR_DEPTH-1 loop
				if I=0 then
					q(I) <= din;
				else
					q(I) <= q(I-1);
				end if;
			end loop;
		end if;
	end process;

end Behavioral;
