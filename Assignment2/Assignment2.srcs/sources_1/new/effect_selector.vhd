library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity effect_selector is
    generic(
        JSTK_BITS  : integer := 10
    );
    Port (
        aclk 		: in STD_LOGIC;
        aresetn		: in STD_LOGIC;
        effect		: in STD_LOGIC;
        jstck_x		: in STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        jstck_y		: in STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        volume		: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        balance		: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0);
        jstk_y_lfo	: out STD_LOGIC_VECTOR(JSTK_BITS-1 downto 0)
    );
end effect_selector;

architecture Behavioral of effect_selector is

    -- init all outputs at 512 (jstk center position)
    constant JSTK_INIT      : std_logic_vector(JSTK_BITS-1 downto 0) := std_logic_vector(to_unsigned((2**JSTK_BITS)/2 , JSTK_BITS));

    signal volume_reg       : std_logic_vector(volume'RANGE)         := JSTK_INIT;
    signal balance_reg      : std_logic_vector(balance'RANGE)        := JSTK_INIT;
    signal lfo_period_reg   : std_logic_vector(jstk_y_lfo'RANGE)     := JSTK_INIT;

begin

    -- register used to keep the last valid input before the effect button changes state
    volume      <= volume_reg;
    balance     <= balance_reg;
    jstk_y_lfo  <= lfo_period_reg;

    process (aclk)      -- synchronous reset

    begin

        if aresetn = '0' then

            volume_reg      <= JSTK_INIT;
            balance_reg     <= JSTK_INIT;
            lfo_period_reg  <= JSTK_INIT;

        elsif rising_edge(aclk) then

            if effect = '0' then
                
                volume_reg  <= jstck_y;
                balance_reg <= jstck_x;

            elsif effect = '1' then

                lfo_period_reg <= jstck_y;

            end if;
            
        end if;

    end process;

end Behavioral;