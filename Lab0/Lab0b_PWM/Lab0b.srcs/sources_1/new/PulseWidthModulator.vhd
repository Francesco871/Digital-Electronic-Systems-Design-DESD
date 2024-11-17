library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PulseWidthModulator is
	Generic(
		BIT_LENGTH : INTEGER RANGE 1 TO 16 := 8; -- Bit used inside PWM
		T_ON_INIT : POSITIVE := 64; -- Init of Ton
		PERIOD_INIT : POSITIVE := 128; -- Init of Periof
		PWM_INIT : STD_LOGIC:= '0' -- Init of PWM
	);
	Port (
		------- Reset/Clock --------
		reset : IN STD_LOGIC;
		clk : IN STD_LOGIC;
		----------------------------
		-------- Duty Cycle ----------
		Ton : IN STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0); -- clk at PWM = '1'
		Period : IN STD_LOGIC_VECTOR(BIT_LENGTH-1 downto 0); -- clk per period of PWM
		PWM : OUT STD_LOGIC -- PWM signal
		----------------------------
	);
end PulseWidthModulator;

architecture Behavioral of PulseWidthModulator is
	-- VERSIONE FATTA DA ME ERRATA IN CASI PARTICOLARI ==> VEDI SOLUZIONE PROF
	signal my_counter : std_logic_vector(BIT_LENGTH-1 downto 0) := (Others => '0');
	signal Ton_reg : std_logic_vector(BIT_LENGTH-1 DOWNTO 0) := std_logic_vector(to_unsigned(T_ON_INIT,BIT_LENGTH));
	signal period_reg : std_logic_vector(BIT_LENGTH-1 DOWNTO 0) := std_logic_vector(to_unsigned(PERIOD_INIT,BIT_LENGTH));
--uso registri per Ton e periodo in modo che se Ton e periodo effettivi cambiano durante il periodo non risultano in pwm errato, Ton e il periodo si aggiornano alla fine del periodo
begin
	process(clk, reset)
	begin
		if reset = '1' then
			my_counter <= (Others => '0');
			PWM <= PWM_INIT;

			Ton_reg <= std_logic_vector(to_unsigned(T_ON_INIT,Ton_reg'LENGTH));
			period_reg <= std_logic_vector(to_unsigned(PERIOD_INIT,period_reg'LENGTH));
		elsif rising_edge(clk) then
			my_counter <= std_logic_vector(unsigned(my_counter) +1);

			if my_counter >= period_reg then
				my_counter <= (Others => '0');
				PWM <= '1';

				Ton_reg <= Ton;
				period_reg <= Period;
			else
				if Ton_reg > period_reg then
					PWM <= '1';
				elsif my_counter = Ton_reg then
					PWM <= '0';
				end if;
			end if;
		end if;
	end process;


end Behavioral;
