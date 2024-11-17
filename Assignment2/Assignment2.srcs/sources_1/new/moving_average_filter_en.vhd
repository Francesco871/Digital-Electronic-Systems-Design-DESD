library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity moving_average_filter_en is
	generic (
		-- Filter order expressed as 2^(FILTER_ORDER_POWER)
		FILTER_ORDER_POWER	: integer	:= 5;

		TDATA_WIDTH			: positive	:= 24
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

		enable_filter	: in std_logic
	);
end moving_average_filter_en;

architecture Behavioral of moving_average_filter_en is

	-- FSM to handle the communication
	type state_type is (RST, RECEIVE_LEFT, RECEIVE_RIGHT, SEND_LEFT, SEND_RIGHT);

	signal state    			: state_type := RST;

	type fifo_type is array (0 to 2**FILTER_ORDER_POWER-1) of signed(TDATA_WIDTH-1 downto 0);

	-- 2 FIFO used to save the 32 samples that we have to average
    signal left_fifo 			: fifo_type := (others => (others => '0'));
    signal right_fifo 			: fifo_type := (others => (others => '0'));

	signal enable_filter_reg 	: std_logic := '0';

    -- bigger signals to accomodate the sum of the 32 samples
	signal left_sum 			: signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 downto 0) := (others => '0');
    signal right_sum 			: signed(TDATA_WIDTH + FILTER_ORDER_POWER - 1 downto 0) := (others => '0');

	-- last sample that came out from the FIFO
	signal left_last 			: signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_last 			: signed(TDATA_WIDTH-1 downto 0) := (others => '0');

	signal left_out     		: signed(TDATA_WIDTH-1 downto 0) := (others => '0');
    signal right_out    		: signed(TDATA_WIDTH-1 downto 0) := (others => '0');

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
	
	-- effect controller
	with enable_filter_reg select left_out <= 
		resize(shift_right(left_sum, FILTER_ORDER_POWER), TDATA_WIDTH) 	when '1',
		left_fifo(0) 													when others;

	with enable_filter_reg select right_out <= 
		resize(shift_right(right_sum, FILTER_ORDER_POWER), TDATA_WIDTH) when '1',
		right_fifo(0) 													when others;

	-- output manager
	with state select m_axis_tdata <=
		std_logic_vector(left_out)        when SEND_LEFT,
		std_logic_vector(right_out)       when SEND_RIGHT,
		(others => '-') when others;

	process(aclk)   -- synchronous reset
    begin

        if aresetn = '0' then

            state <= RST;
			
			enable_filter_reg 	<= '0';
			left_fifo 			<= (others => (others => '0'));
    		right_fifo 			<= (others => (others => '0'));
			left_last 			<= (others => '0');
			right_last 			<= (others => '0');
			left_sum 			<= (others => '0');
			right_sum 			<= (others => '0');

        elsif rising_edge(aclk) then

            case state is

                when RST =>

                    state <= RECEIVE_LEFT;

                when RECEIVE_LEFT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '0' then

                        left_last <= left_fifo(left_fifo'HIGH);											-- save the sample that is leaving the FIFO
						left_fifo <= signed(s_axis_tdata) & left_fifo(0 to 2**FILTER_ORDER_POWER - 2);  -- shift FIFO samples and save the new one

                        state 	  <= RECEIVE_RIGHT;

                    end if;

                when RECEIVE_RIGHT =>

                    if s_axis_tvalid = '1' and s_axis_tlast = '1' then

						right_last 			<= right_fifo(right_fifo'HIGH);											-- save the sample that is leaving the FIFO
                        right_fifo 			<= signed(s_axis_tdata) & right_fifo(0 to 2**FILTER_ORDER_POWER - 2);   -- shift FIFO samples and save the new one
						enable_filter_reg 	<= enable_filter;														-- refresh filter enable only here to have the same packet of L and R channel filtered at the same time
						left_sum 			<= (left_sum - left_last) + left_fifo(0);								-- calculate the new sum exploiting the previous sum (left computed here so it's ready when the FSM enters SEND_LEFT state)

                        state 				<= SEND_LEFT;

                    end if;

                when SEND_LEFT =>

                    if m_axis_tready = '1' then

						right_sum	<= (right_sum - right_last) + right_fifo(0);  -- calculate the new sum exploiting the previous sum (right computed here so it's ready when the FSM enters SEND_RIGHT state)

                        state 		<= SEND_RIGHT;

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