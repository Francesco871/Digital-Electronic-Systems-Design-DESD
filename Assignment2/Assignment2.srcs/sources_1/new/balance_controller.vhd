library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity balance_controller is
	generic (
		TDATA_WIDTH		: positive := 24;
		BALANCE_WIDTH	: positive := 10;
		BALANCE_STEP_2	: positive := 6		-- i.e., balance_values_per_step = 2**BALANCE_STEP_2
	);
	Port (
		aclk			: in std_logic;
		aresetn			: in std_logic;

		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(TDATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;
		s_axis_tlast	: in std_logic;

		m_axis_tvalid	: out std_logic;
		m_axis_tdata	: out std_logic_vector(TDATA_WIDTH-1 downto 0);
		m_axis_tready	: in std_logic;
		m_axis_tlast	: out std_logic;

		balance			: in std_logic_vector(BALANCE_WIDTH-1 downto 0)
	);
end balance_controller;

architecture Behavioral of balance_controller is

    constant BALANCE_INTERVAL       : integer := 2**BALANCE_STEP_2;
    constant HALF_BALANCE_INTERVAL  : integer := (2**BALANCE_STEP_2)/2;
    constant BALANCE_LEVEL_MAX      : integer := (2**BALANCE_WIDTH / 2) / 2**BALANCE_STEP_2;

    -- FSM to handle the communication
    type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT, SEND_LEFT, SEND_RIGHT);

    signal state                    : state_type := RST;

    signal left_reg                 : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_reg                : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

    signal balance_level            : integer range -BALANCE_LEVEL_MAX to BALANCE_LEVEL_MAX := 0; 
    signal balance_reg              : integer range -BALANCE_LEVEL_MAX to BALANCE_LEVEL_MAX := 0;

    signal left_out                 : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_out                : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

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

    -- this function (balance_level = ((balance + 32)/64) - 8     compute the balance level ( i.e. the exponent used to amplify the audio as audio*(2**balance_level) )
    balance_level <= to_integer((unsigned(balance) + HALF_BALANCE_INTERVAL) / BALANCE_INTERVAL) - BALANCE_LEVEL_MAX;

    -- balance control
    left_out    <= 
        shift_right(left_reg, balance_reg)      when balance_reg > 0 else
        left_reg;

    right_out   <=
        shift_right(right_reg, -balance_reg)    when balance_reg < 0 else
        right_reg;
        
    -- output manager
    with state select m_axis_tdata <=
        std_logic_vector(left_out)              when SEND_LEFT,
        std_logic_vector(right_out)             when SEND_RIGHT,
        (others => '-')                         when others;

    process(aclk)   -- synchronous reset
    begin

        if aresetn = '0' then

            state           <= RST;

            balance_reg     <= 0;
            left_reg        <= (others => '0');
            right_reg       <= (others => '0');

        elsif rising_edge(aclk) then

            case state is

                when RST =>

                    state   <= RECEIVE_LEFT;

                when RECEIVE_LEFT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then

                        left_reg    <= signed(s_axis_tdata);

                        state       <= RECEIVE_RIGHT;

                    end if;

                when RECEIVE_RIGHT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then

                        right_reg   <= signed(s_axis_tdata);
                        balance_reg <= balance_level;               -- refresh balance only here to be consistent on the same packet of data (L and R)

                        state       <= SEND_LEFT;

                    end if;

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