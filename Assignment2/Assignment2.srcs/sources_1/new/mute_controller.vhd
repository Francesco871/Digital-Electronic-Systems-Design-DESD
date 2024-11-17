library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mute_controller is
	Generic (
		TDATA_WIDTH		: positive := 24
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

		mute			: in std_logic
	);
end mute_controller;

architecture Behavioral of mute_controller is

	-- FSM to handle the communication
	type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT, SEND_LEFT, SEND_RIGHT);

    signal state    	: state_type := RST;

	signal mute_reg 	: std_logic := '0';

    signal left_reg     : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_reg    : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

	signal left_out     : signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_out    : signed(TDATA_WIDTH-1 downto 0) := (others => '0');

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

	-- mute control
	with mute_reg select left_out <= 
		(others => '0') when '1',
		left_reg 		when others;

	with mute_reg select right_out <= 
		(others => '0') when '1',
		right_reg 		when others;

	-- output manager
	with state select m_axis_tdata <=
		std_logic_vector(left_out)        	when SEND_LEFT,
		std_logic_vector(right_out)       	when SEND_RIGHT,
		(others => '-') 					when others;


	process(aclk)   -- synchronous reset
    begin

        if aresetn = '0' then

            state 		<= RST;

			mute_reg 	<= '0';
            left_reg    <= (others => '0');
            right_reg   <= (others => '0');

        elsif rising_edge(aclk) then

            case state is

                when RST =>

                    state <= RECEIVE_LEFT;

                when RECEIVE_LEFT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then

                        left_reg 	<= signed(s_axis_tdata);

                        state 		<= RECEIVE_RIGHT;

                    end if;

                when RECEIVE_RIGHT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then

                        right_reg 	<= signed(s_axis_tdata);
						mute_reg 	<= mute;						-- refresh mute enable only here to have the same packet of L and R channel muted at the same time

                        state 		<= SEND_LEFT;

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