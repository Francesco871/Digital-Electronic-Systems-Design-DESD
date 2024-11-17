--	we decided to perform the communication between the PC and the FPGA with 2 FSM:
--	1 for sending joystick data from the FPGA to the PC (tx_state)
--	1 for receiving leds data from the PC (rx_state)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity jstk_uart_bridge is
	generic (
		HEADER_CODE		: std_logic_vector(7 downto 0) := x"c0"; -- Header of the packet
		TX_DELAY		: positive := 1_000_000;    -- Pause (in clock cycles) between two packets
		JSTK_BITS		: integer range 1 to 7 := 7    -- Number of bits of the joystick axis to transfer to the PC 
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the PC (i.e., joystick position and buttons state)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the PC (i.e., LED color)
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);
		s_axis_tready	: out STD_LOGIC;

		jstk_x			: in std_logic_vector(9 downto 0);
		jstk_y			: in std_logic_vector(9 downto 0);
		btn_jstk		: in std_logic;
		btn_trigger		: in std_logic;

		led_r			: out std_logic_vector(7 downto 0);
		led_g			: out std_logic_vector(7 downto 0);
		led_b			: out std_logic_vector(7 downto 0)
	);
end jstk_uart_bridge;

architecture Behavioral of jstk_uart_bridge is

	type tx_state_type is (TX_RESET, DELAY, SEND_HEADER, SEND_JSTK_X, SEND_JSTK_Y, SEND_BUTTONS);
	type rx_state_type is (RX_RESET, LOOK_FOR_HEADER, RECEIVE_LED_R, RECEIVE_LED_G, RECEIVE_LED_B);

	-- at the beginning, both the tx and the rx start at the reset state
	signal tx_state : tx_state_type := TX_RESET;
	signal rx_state : rx_state_type := RX_RESET;

	-- counter needed to wait for the given delay (TX_DELAY)
	signal tx_counter : integer range 0 to TX_DELAY := 0;

	-- signal needed because our data bus is 8 bit, while we pass to the PC only JSTK_BITS bits.
    signal zero : std_logic_vector(8-JSTK_BITS-1 downto 0) := (Others => '0');

	-- signals used to store led values to pass them concurrently, when the whole packet is received
	signal led_r_reg : std_logic_vector(led_r'RANGE) := (Others => '0');
	signal led_g_reg : std_logic_vector(led_g'RANGE) := (Others => '0');

begin

	FSM : process(aclk)

	begin

		if rising_edge(aclk) then

			-- we decided to implement a syncronous reset
			if aresetn = '0' then

				-- TX reset
				tx_state <= TX_RESET;
				tx_counter <= 0;
				m_axis_tvalid <= '0';

				-- RX reset
				rx_state <= RX_RESET;
				s_axis_tready <= '0';

				led_r <= (Others => '0');
				led_g <= (Others => '0');
				led_b <= (Others => '0');				
			
			else 

				-- transmitter
				case tx_state is

					when TX_RESET =>

						tx_state <= DELAY;

					when DELAY => 

						tx_counter <= tx_counter + 1;

						if tx_counter = TX_DELAY - 1 then		-- TX_DELAY - 1 to wait for TX_DELAY clk cylces due to signal commit

							tx_counter <= 0;
							tx_state <= SEND_HEADER;

						end if;

						m_axis_tvalid <= '0';  -- needed to reset the tvalid when the previous state is "SEND_BUTTONS"

					when SEND_HEADER =>

						m_axis_tvalid <= '1';			-- put tvalid = '1' beacuse now we have valid data on tdata bus
						m_axis_tdata <= HEADER_CODE;	-- send header so the receiver can understand when a new packet begins

							if m_axis_tready = '1' then		-- change state only when the axis slave is ready to receive the next data

								tx_state <= SEND_JSTK_X;							

							end if;
					
					when SEND_JSTK_X =>

							m_axis_tdata <= zero & jstk_x(jstk_x'HIGH downto jstk_x'HIGH-JSTK_BITS+1);  -- put on the bus the first JTSK_BITS MSB of jstk_x

						if m_axis_tready = '1' then		-- change state only when the axis slave is ready to receive the next data


							tx_state <= SEND_JSTK_Y;

						end if;

					when SEND_JSTK_Y => 

							m_axis_tdata <= zero & jstk_y(jstk_y'HIGH downto jstk_y'HIGH-JSTK_BITS+1);  -- put on the bus the first JTSK_BITS MSB of jstk_y

						if m_axis_tready = '1' then		-- change state only when the axis slave is ready to receive the next data

							tx_state <= SEND_BUTTONS;

						end if;

					when SEND_BUTTONS =>

						m_axis_tdata <= (0 => btn_jstk, 1 => btn_trigger, Others => '0');

						if m_axis_tready = '1' then		-- change state only when the axis slave is ready to receive the next data

							tx_state <= DELAY;				

						end if;

				end case;

				-- receiver
				case rx_state is

					when RX_RESET =>

						rx_state <= LOOK_FOR_HEADER;
						s_axis_tready <= '1';			-- we are ready to receive the data from the axis master

					when LOOK_FOR_HEADER =>

						if s_axis_tvalid = '1' then			-- proceed only if the data we are receving is valid

							if s_axis_tdata = HEADER_CODE then		-- header found

								rx_state <= RECEIVE_LED_R;

							end if;

						end if;

					when RECEIVE_LED_R =>

						if s_axis_tvalid = '1' then			-- proceed only if the data we are receving is valid
							
							led_r_reg <= s_axis_tdata;
							rx_state <= RECEIVE_LED_G;

						end if ;

					when RECEIVE_LED_G =>

						if s_axis_tvalid = '1' then			-- proceed only if the data we are receving is valid

							led_g_reg <= s_axis_tdata;
							rx_state <= RECEIVE_LED_B;

						end if;

					when RECEIVE_LED_B =>

						if s_axis_tvalid = '1' then			-- proceed only if the data we are receving is valid

							rx_state <= LOOK_FOR_HEADER;

							led_r <= led_r_reg;				-- we decided to put the leds data on the output only in the last state, beacuse they belong to the same packet of bytes
							led_g <= led_g_reg;
							led_b <= s_axis_tdata;

						end if;

				end case;

			end if;

		end if;

	end process;

end architecture;
