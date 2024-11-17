library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LFO is
    generic(
        CHANNEL_LENGTH	            : integer := 24;
        JOYSTICK_LENGTH	            : integer := 10;
        CLK_PERIOD_NS	            : integer := 10;
        TRIANGULAR_COUNTER_LENGTH	: integer := 10 -- Triangular wave period length
    );
    Port (        
            aclk			: in std_logic;
            aresetn			: in std_logic;
            
            jstk_y          : in std_logic_vector(JOYSTICK_LENGTH-1 downto 0);
            
            lfo_enable      : in std_logic;
    
            s_axis_tvalid	: in std_logic;
            s_axis_tdata	: in std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            s_axis_tlast    : in std_logic;
            s_axis_tready	: out std_logic;
    
            m_axis_tvalid	: out std_logic;
            m_axis_tdata	: out std_logic_vector(CHANNEL_LENGTH-1 downto 0);
            m_axis_tlast	: out std_logic;
            m_axis_tready	: in std_logic
        );
end entity LFO;

architecture Behavioral of LFO is

    constant LFO_COUNTER_BASE_PERIOD_US : integer := 1000; -- Base period of the LFO counter in us
    constant ADJUSTMENT_FACTOR          : integer := 90; -- Multiplicative factor to scale the LFO period properly with the joystick y position

    constant LFO_COUNTER_BASE_PERIOD    : integer := (LFO_COUNTER_BASE_PERIOD_US * 1000) / CLK_PERIOD_NS;
    constant LFO_PERIOD_INIT            : integer := LFO_COUNTER_BASE_PERIOD - (ADJUSTMENT_FACTOR *  (2**JOYSTICK_LENGTH / 2));     -- initialized with the lfo_period computed with the jstk centered (512)
    constant MINIMUM_LFO_PERIOD         : integer := LFO_COUNTER_BASE_PERIOD - (ADJUSTMENT_FACTOR *  (2**JOYSTICK_LENGTH));         -- min lfo_period when the jstk is on the top (1024)

    constant MAX_TRI_COUNTER            : integer := 2**TRIANGULAR_COUNTER_LENGTH;
    
    -- FSM to handle the communication
    type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT, MUL_REG, OUT_REG, SEND_LEFT, SEND_RIGHT);

	signal state                    : state_type := RST;

    -- prescaler to count how many clk cycles there are in one period step
    signal clk_cycles_counter       : integer range 1 to LFO_COUNTER_BASE_PERIOD := 1;
    signal lfo_period               : integer range MINIMUM_LFO_PERIOD to LFO_COUNTER_BASE_PERIOD := LFO_PERIOD_INIT;
    signal lfo_period_reg           : integer range MINIMUM_LFO_PERIOD to LFO_COUNTER_BASE_PERIOD := LFO_PERIOD_INIT;

    signal dir                      : std_logic := '1';     -- 1 -> direction up   |   0 -> direction down

    -- we choose to modulate the signal between 0 and 1023/1024 (almost 1) with the triangular wave
    signal triangular_counter       : unsigned(TRIANGULAR_COUNTER_LENGTH-1 downto 0) := (others => '0');
    signal triangular_counter_reg   : integer range 0 to MAX_TRI_COUNTER-1 := 0;

	signal left_reg                 : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');
	signal right_reg                : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');

    signal left_mul                 : signed(2*CHANNEL_LENGTH-1 downto 0)  := (others => '0');
	signal right_mul                : signed(2*CHANNEL_LENGTH-1 downto 0)  := (others => '0');

    signal left_mul_reg             : signed(2*CHANNEL_LENGTH-1 downto 0)  := (others => '0');
	signal right_mul_reg            : signed(2*CHANNEL_LENGTH-1 downto 0)  := (others => '0');
    
    signal left_out                 : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');
	signal right_out                : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');

    signal left_out_reg             : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');
	signal right_out_reg            : signed(CHANNEL_LENGTH-1 downto 0)    := (others => '0');

begin

    -- mux to manage correctly AXIS protocol
    with state select m_axis_tvalid <=
        '1' when SEND_LEFT,
        '1' when SEND_RIGHT,
        '0' when others;

    with state select m_axis_tlast <=
        '0' when SEND_LEFT,
        '1' when SEND_RIGHT,
        '-' when others;

    with state select s_axis_tready <=
        '1' when RECEIVE_LEFT,
        '1' when RECEIVE_RIGHT,
        '0' when others;

    left_mul    <= left_reg * triangular_counter_reg;
    right_mul   <= right_reg * triangular_counter_reg;
    
    -- lfo controller
    with lfo_enable select left_out <=
        resize(shift_right(left_mul_reg, TRIANGULAR_COUNTER_LENGTH), CHANNEL_LENGTH)    when '1',
        left_reg                                                                        when others;

    with lfo_enable select right_out <=
        resize(shift_right(right_mul_reg, TRIANGULAR_COUNTER_LENGTH), CHANNEL_LENGTH)   when '1',
        right_reg                                                                       when others;

    -- output manager
    with state select m_axis_tdata <=
        std_logic_vector(left_out_reg)  when SEND_LEFT,
        std_logic_vector(right_out_reg) when SEND_RIGHT,
        (others => '-') 			    when others;
    
    lfo_period <= LFO_COUNTER_BASE_PERIOD - (ADJUSTMENT_FACTOR * to_integer(unsigned(jstk_y)));

    -- process to create the triangular wave
    triangle : process(aclk)    -- synchronous reset
    begin

        if aresetn = '0' then

            clk_cycles_counter  <= 1;
            lfo_period_reg      <= LFO_PERIOD_INIT;
            triangular_counter  <= (others => '0');
            dir                 <= '1';            

        elsif rising_edge(aclk) then

            clk_cycles_counter <= clk_cycles_counter + 1;

            if clk_cycles_counter = lfo_period_reg then

                clk_cycles_counter <= 1;
                
                lfo_period_reg <= lfo_period;       -- refresh lfo_period_reg only here, when the previous step has finished

                if dir = '1' then

                    if triangular_counter = MAX_TRI_COUNTER - 2 then        
                         
                        dir <= '0';                                     -- change direction
                    
                    end if;

                    triangular_counter <= triangular_counter + 1;

                elsif dir = '0' then

                    if triangular_counter = 1 then

                        dir <= '1';                                     -- change direction
                    
                    end if;

                    triangular_counter <= triangular_counter - 1;

                end if;

            end if;

        end if;

    end process;
    
    -- process to handle the communication
    FSM : process(aclk)   -- synchronous reset
    begin
        
        if aresetn = '0' then
        
            state <= RST;
        
            triangular_counter_reg  <= 0;
            left_reg                <= (others => '0');
            right_reg               <= (others => '0');
            left_mul_reg            <= (others => '0');
            right_mul_reg           <= (others => '0');
            left_out_reg            <= (others => '0');
            right_out_reg           <= (others => '0');
        
        elsif rising_edge(aclk) then
        
            case state is
        
                when RST =>
        
                    state <= RECEIVE_LEFT;
        
                when RECEIVE_LEFT =>
        
                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then
        
                        left_reg    <= signed(s_axis_tdata);
        
                        state       <= RECEIVE_RIGHT;
        
                    end if;
        
                when RECEIVE_RIGHT =>
        
                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then
        
                        right_reg               <= signed(s_axis_tdata);
                        triangular_counter_reg  <= to_integer(triangular_counter);      -- refresh triangular counter only here to have both L and R channel modulated in the same way
        
                        state                   <= MUL_REG;
        
                    end if;


                when MUL_REG =>                 -- multiplication sample state, useful to reach 180MHz (pipeline)

                    left_mul_reg    <= left_mul;
                    right_mul_reg   <= right_mul;

                    state           <= OUT_REG;

                when OUT_REG =>                 -- out sample state, useful to reach 180MHz (pipeline)

                    left_out_reg    <= left_out;
                    right_out_reg   <= right_out;

                    state           <= SEND_LEFT;
        
                when SEND_LEFT =>
        
                    if m_axis_tready = '1' then

                        state <= SEND_RIGHT;
        
                    end if;
        
                when SEND_RIGHT =>
        
                    if m_axis_tready = '1' then
        
                        state <= RECEIVE_LEFT;
        
                    end if;
        
                when others =>
        
                    state <= RST;
        
            end case;
        
        end if;
        
    end process;
    
end Behavioral;
