library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_level_controller is
    generic(
        NUM_LEDS 		: positive := 16;
        CHANNEL_LENGTH  : positive := 24;
        refresh_time_ms	: positive := 1;
        clock_period_ns	: positive := 10
    );
    Port (
        
        aclk			: in std_logic;
        aresetn			: in std_logic;
        
        led  			: out std_logic_vector(NUM_LEDS-1 downto 0);

        s_axis_tvalid	: in std_logic;
        s_axis_tdata	: in std_logic_vector(CHANNEL_LENGTH-1 downto 0);
        s_axis_tlast    : in std_logic;
        s_axis_tready	: out std_logic

    );
end led_level_controller;

architecture Behavioral of led_level_controller is

    constant REFRESH_TIME_CYCLES : integer := refresh_time_ms * (1_000_000 / clock_period_ns);

    constant DATA_LED_DIFFERENCE : integer := CHANNEL_LENGTH - NUM_LEDS;

    -- FSM to handle the communication
    type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT);

    signal state                : state_type := RST;

    signal clk_cycles_counter   : integer range 0 to REFRESH_TIME_CYCLES := 0;

    -- length is CHANNEL_LENGTH+1 to be summed avoiding overflow
    signal left_reg             : unsigned(CHANNEL_LENGTH downto 0)     := (others => '0');
    signal right_reg            : unsigned(CHANNEL_LENGTH downto 0)     := (others => '0');

    signal average              : unsigned(CHANNEL_LENGTH-1 downto 0)   := (others => '0');

    signal led_out              : std_logic_vector(NUM_LEDS-1 downto 0) := (others => '0');

begin

    -- mux to manage correctly AXIS protocol
    with state select s_axis_tready <=
        '1' when RECEIVE_LEFT,
        '1' when RECEIVE_RIGHT,
        '0' when others;

    average <= resize(shift_right(left_reg + right_reg, 1), CHANNEL_LENGTH);
    
    led_out(NUM_LEDS - 1) <= average(CHANNEL_LENGTH - 1);                       -- when average >= 2^23 leftmost led on

    LEDS_GEN : for I in CHANNEL_LENGTH - 2 downto DATA_LED_DIFFERENCE generate  -- this loop implement the logic to drive the others leds 

        led_out(I - DATA_LED_DIFFERENCE) <= average(I) or led_out(I - DATA_LED_DIFFERENCE + 1);   -- this OR turns on the led if it's the first led to be turned on or the previous led is on (after the first led turned on, all the leds on its right are turned on) 

    end generate;

    -- process to refresh leds every refresh_time_ms
    LEDS_REFRESH : process(aclk)    -- synchronous reset
    begin

        if aresetn = '0' then

            clk_cycles_counter <= 0;

        elsif rising_edge(aclk) then

            clk_cycles_counter <= clk_cycles_counter + 1;

            if clk_cycles_counter = REFRESH_TIME_CYCLES - 1 then

                clk_cycles_counter <= 0;

                led <= led_out;             -- leds refreshed

            end if;

        end if;

    end process;  

    -- process to handle the communication
    FSM : process(aclk)   -- synchronous reset
    begin

        if aresetn = '0' then

            state       <= RST;

            left_reg    <= (others => '0');
            right_reg   <= (others => '0');

        elsif rising_edge(aclk) then

            case state is

                when RST =>

                    state <= RECEIVE_LEFT;

                when RECEIVE_LEFT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then

                        left_reg    <= resize(unsigned(abs(signed(s_axis_tdata))), CHANNEL_LENGTH + 1);     -- save the absolute value to average on the magnitude

                        state       <= RECEIVE_RIGHT;

                    end if;

                when RECEIVE_RIGHT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then

                        right_reg    <= resize(unsigned(abs(signed(s_axis_tdata))), CHANNEL_LENGTH + 1);    -- save the absolute value to average on the magnitude

                        state        <= RECEIVE_LEFT;

                    end if;

                when others =>

                    state <= RST;

            end case;

        end if;

    end process;

end Behavioral;
