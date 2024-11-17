library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ShiftRegister_v2 is
	Generic(
		SR_WIDTH : NATURAL := 8;
		SR_DEPTH : POSITIVE := 4;
		SR_INIT : INTEGER := 0
	);
	Port (
 		reset : IN STD_LOGIC;
		clk : IN STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(SR_WIDTH-1 downto 0);
		dout : OUT STD_LOGIC_VECTOR(SR_WIDTH-1 downto 0)
	);
end ShiftRegister_v2;

architecture Behavioral of ShiftRegister_v2 is
	type NestedArray is array (0 to SR_DEPTH-1) of STD_LOGIC_VECTOR (SR_WIDTH-1 downto 0);
	signal q : NestedArray := (Others => std_logic_vector(to_unsigned(SR_INIT,SR_WIDTH)));
	-- oppure usavo una costante per inizializzare:
	--  constant INIT : std_logic_vector(SR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(SR_INIT,SR_WIDTH));
begin

	dout <= q(SR_DEPTH-1);

	process(clk, reset)
	begin
		if reset = '1' then
			q <= (Others => std_logic_vector(to_unsigned(SR_INIT,SR_WIDTH)));
		elsif rising_edge(clk) then
			q <= din & q(0 to SR_DEPTH-2); -- == shifto a dx q eliminando l'ultimo elemento e inserisco a sx din
--			Oppure col for:
--			ff : for I in 0 to SR_DEPTH-1 loop
--				if I=0 then
--					q(I) <= din;
--				else
--					q(I) <= q(I-1);
--				end if;
--			end loop;
		end if;
	end process;

end Behavioral;
