library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity volume_controller is
	Generic (
		TDATA_WIDTH		: positive  := 24;
		VOLUME_WIDTH	: positive  := 10;
		VOLUME_STEP_2	: positive  := 6;		    -- i.e., volume_values_per_step = 2**VOLUME_STEP_2
		HIGHER_BOUND	: integer   := 2**23-1;	    -- Inclusive
		LOWER_BOUND		: integer   := -8388608		-- Inclusive
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tlast	: in std_logic;
		s_axis_tready	: out std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tlast	: out std_logic;
		m_axis_tready	: in std_logic;

		volume		    : in std_logic_vector(VOLUME_WIDTH-1 downto 0)
	);
end volume_controller;

architecture Behavioral of volume_controller is

	constant VOLUME_INTERVAL        : integer := 2**VOLUME_STEP_2;
	constant HALF_VOLUME_INTERVAL   : integer := (2**VOLUME_STEP_2)/2;
    constant VOLUME_LEVEL_MAX       : integer := (2**VOLUME_WIDTH / 2) / 2**VOLUME_STEP_2;

	-- FSM to handle the communication
    type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT, OUT_REG , SEND_LEFT, SEND_RIGHT);

	signal state                    : state_type := RST;

	signal left_reg                 : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
	signal right_reg                : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

	signal volume_level             : integer range -VOLUME_LEVEL_MAX to VOLUME_LEVEL_MAX := 0; 
	signal volume_reg               : integer range -VOLUME_LEVEL_MAX to VOLUME_LEVEL_MAX := 0;
    
    signal left_out                 : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
	signal right_out                : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

    signal left_out_reg             : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
	signal right_out_reg            : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

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

    -- this function (volume_level = ((volume + 32)/64) - 8     compute the volume level ( i.e. the exponent used to amplify the audio as audio*(2**volume_level) )
    volume_level <= to_integer((unsigned(volume) + HALF_VOLUME_INTERVAL) / VOLUME_INTERVAL) - VOLUME_LEVEL_MAX;
    
    -- amplification and saturation control  
    left_out    <=
        shift_right(left_reg , -volume_reg)     when volume_reg < 0                                                                           else
        to_signed(LOWER_BOUND, TDATA_WIDTH)     when shift_left(resize(left_reg, TDATA_WIDTH + VOLUME_LEVEL_MAX), volume_reg) < LOWER_BOUND   else
        to_signed(HIGHER_BOUND, TDATA_WIDTH)    when shift_left(resize(left_reg, TDATA_WIDTH + VOLUME_LEVEL_MAX), volume_reg) > HIGHER_BOUND  else
        shift_left(left_reg, volume_reg);

    right_out   <=
        shift_right(right_reg , -volume_reg)    when volume_reg < 0                                                                            else
        to_signed(LOWER_BOUND, TDATA_WIDTH)     when shift_left(resize(right_reg, TDATA_WIDTH + VOLUME_LEVEL_MAX), volume_reg) < LOWER_BOUND   else
        to_signed(HIGHER_BOUND, TDATA_WIDTH)    when shift_left(resize(right_reg, TDATA_WIDTH + VOLUME_LEVEL_MAX), volume_reg) > HIGHER_BOUND  else
        shift_left(right_reg, volume_reg);
        
    -- output manager
    with state select m_axis_tdata <=
        std_logic_vector(left_out_reg)          when SEND_LEFT,
        std_logic_vector(right_out_reg)         when SEND_RIGHT,
        (others => '-') when others;

    process(aclk)   -- synchronous reset
    begin

        if aresetn = '0' then

            state           <= RST;

            volume_reg      <= 0;
            left_reg        <= (others => '0');
            right_reg       <= (others => '0');
            left_out_reg    <= (others => '0');
            right_out_reg   <= (others => '0');

        elsif rising_edge(aclk) then

            case state is

                when RST =>

                    state <= RECEIVE_LEFT;

                when RECEIVE_LEFT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then

                        left_reg        <= signed(s_axis_tdata);

                        state           <= RECEIVE_RIGHT;

                    end if;

                when RECEIVE_RIGHT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then

                        right_reg       <= signed(s_axis_tdata);
                        volume_reg      <= volume_level;                -- refresh volume only here to have both L and R channel amplified in the same way

                        state           <= OUT_REG;

                    end if;

                when OUT_REG =>                                         -- out sample state, useful to reach 180MHz (pipeline)

                    left_out_reg        <= left_out;    
                    right_out_reg       <= right_out;

                    state               <= SEND_LEFT;

                when SEND_LEFT =>

                    if m_axis_tready = '1' then

                        state           <= SEND_RIGHT;

                    end if;

                when SEND_RIGHT =>

                    if m_axis_tready = '1' then

                        state           <= RECEIVE_LEFT;

                    end if;

                when others =>

                    state               <= RST;

            end case;

        end if;

    end process;

end Behavioral;
