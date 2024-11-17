---------- DEFAULT LIBRARY ---------
library IEEE;
    use IEEE.STD_LOGIC_1164.all;
    use IEEE.NUMERIC_STD.ALL;
------------------------------------

entity KittCar is
    Generic (

        CLK_PERIOD_NS           :   POSITIVE    RANGE   1   TO  100     := 10;  -- clk period in nanoseconds
        MIN_KITT_CAR_STEP_MS    :   POSITIVE    RANGE   1   TO  2000    := 2000;    -- Minimum step period in milliseconds (i.e., value in milliseconds of Delta_t)

        NUM_OF_SWS      :   INTEGER RANGE   1 TO 16 := 16;  -- Number of input switches
        NUM_OF_LEDS     :   INTEGER RANGE   1 TO 16 := 16   -- Number of output LEDs

    );
    Port (

        ------- Reset/Clock --------
        reset   :   IN  STD_LOGIC;
        clk     :   IN  STD_LOGIC;
        ----------------------------

        -------- LEDs/SWs ----------
        sw      :   IN  STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);    -- Switches avaiable on Basys3
        leds    :   OUT STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)    -- LEDs avaiable on Basys3
        ----------------------------

    );
end KittCar;

architecture Behavioral of KittCar is

    constant DELTA_t0 : INTEGER := MIN_KITT_CAR_STEP_MS*1000000/CLK_PERIOD_NS;

    signal led_out : STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0) := (0 => '1', Others => '0');
    signal dir : STD_LOGIC := '0';                                                             -- dir = 0 da dx a sx
    signal time_count : UNSIGNED(31 downto 0) := (Others => '0');
    signal sw_count : UNSIGNED(NUM_OF_SWS downto 0) := (Others => '0');
    signal sw_reg : UNSIGNED(NUM_OF_SWS-1 downto 0) := (Others => '0');

begin

    one_led : if NUM_OF_LEDS = 1 generate
        leds <= (Others =>'1');
    end generate;

    n_leds : if NUM_OF_LEDS > 1 generate    

        leds <= led_out;

        process(clk, reset)

        begin

            if reset = '1' then
                led_out <= (0 => '1', Others => '0');
                time_count <= (Others => '0');
                sw_count <= (Others => '0');
                sw_reg <= unsigned(sw);
                dir <= '0';
            elsif rising_edge(clk) then
                time_count <= time_count + 1;
                --sw_reg <= unsigned(sw);
                    if time_count = DELTA_t0 then
                        time_count <= (Others => '0');
                        sw_count <= sw_count + 1;
                        sw_reg <= unsigned(sw);
                        if sw_count >= sw_reg then
                            sw_count <= (Others => '0');
                            if dir = '0' then
                                led_out <= led_out(NUM_OF_LEDS-2 downto 0)&'0';
                                if led_out(NUM_OF_LEDS-2) = '1' then
                                    dir <= '1';
                                end if;
                            elsif dir = '1' then
                                led_out <= '0'&led_out(NUM_OF_LEDS-1 downto 1);
                                if led_out(1) = '1' then
                                    dir <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
            end if;
    
        end process;

    end generate;

end Behavioral;
