--	we decided to perform the communication between the FPGA and the JOYSTICK with 2 FSM:
--	1 for receiving joystick data from the JSTK to the FPGA (rx_state)
--	1 for sending leds data from the FPGA to the JSTK (tx_state)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity digilent_jstk2 is
	generic (
		DELAY_US		: integer := 25;    -- Delay (in us) between two packets
		CLKFREQ		 	: integer := 100_000_000;  -- Frequency of the aclk signal (in Hz)
		SPI_SCLKFREQ 	: integer := 5_000 -- Frequency of the SPI SCLK clock signal (in Hz)
	);
	Port ( 
		aclk 			: in  STD_LOGIC;
		aresetn			: in  STD_LOGIC;

		-- Data going TO the SPI IP-Core (and so, to the JSTK2 module)
		m_axis_tvalid	: out STD_LOGIC;
		m_axis_tdata	: out STD_LOGIC_VECTOR(7 downto 0);
		m_axis_tready	: in STD_LOGIC;

		-- Data coming FROM the SPI IP-Core (and so, from the JSTK2 module)
		-- There is no tready signal, so you must be always ready to accept and use the incoming data, or it will be lost!
		s_axis_tvalid	: in STD_LOGIC;
		s_axis_tdata	: in STD_LOGIC_VECTOR(7 downto 0);

		-- Joystick and button values read from the module
		jstk_x			: out std_logic_vector(9 downto 0);
		jstk_y			: out std_logic_vector(9 downto 0);
		btn_jstk		: out std_logic;
		btn_trigger		: out std_logic;

		-- LED color to send to the module
		led_r			: in std_logic_vector(7 downto 0);
		led_g			: in std_logic_vector(7 downto 0);
		led_b			: in std_logic_vector(7 downto 0)
	);
end digilent_jstk2;

architecture Behavioral of digilent_jstk2 is

	-- Code for the SetLEDRGB command, see the JSTK2 datasheet.
	constant CMDSETLEDRGB		: std_logic_vector(7 downto 0) := x"84";

	-- Do not forget that you MUST wait a bit between two packets. See the JSTK2 datasheet (and the SPI IP-Core README).
	------------------------------------------------------------

	-- compute clk cycles to wait to respect timing of jstk communication
	constant DELAY_CLK_CYCLES : integer := DELAY_US * (CLKFREQ / 1_000_000) + CLKFREQ / SPI_SCLKFREQ;

	type tx_state_type is (TX_RESET, DELAY, SEND_COMMAND, SEND_LED_R, SEND_LED_G, SEND_LED_B, SEND_DUMMY);
	type rx_state_type is (RX_RESET, RECEIVE_JSTK_X_LSB, RECEIVE_JSTK_X_MSB, RECEIVE_JSTK_Y_LSB, RECEIVE_JSTK_Y_MSB, RECEIVE_BUTTONS);

	-- at the beginning, both the tx and the rx start at the reset state
	signal tx_state : tx_state_type := TX_RESET;
	signal rx_state : rx_state_type := RX_RESET;

	-- counter needed to wait for the needed delay to respect jstk SPI timing requirements (DELAY_US)
	signal tx_counter : integer range 0 to DELAY_CLK_CYCLES := 0;

	-- signals used to store jstk coordinates values to pass them concurrently, when the whole packet is received
	signal jstk_x_reg : std_logic_vector(jstk_x'RANGE);
	signal jstk_y_reg : std_logic_vector(jstk_y'RANGE);

begin

	FSM : process(aclk)

	begin

		if rising_edge(aclk) then

			-- we decided to implement a syncronous reset
			if aresetn = '0' then

				--TX reset
				tx_state <= TX_RESET;
				m_axis_tvalid <= '0';
				tx_counter <= 0;

				--RX reset
				rx_state <= RX_RESET;

				jstk_x		<= (Others => '0');
				jstk_y 		<= (Others => '0');
				btn_jstk 	<= '0';
				btn_trigger <= '0';

			else

				-- transmitter
				case tx_state is

					when TX_RESET =>

						tx_state <= DELAY;

					when DELAY =>

						tx_counter <= tx_counter + 1;

						if tx_counter = DELAY_CLK_CYCLES - 1 then		-- DELAY_CLK_CYCLES - 1 to wait for DELAY_CLK_CYCLES clk cylces due to signal commit

							tx_counter <= 0;
							tx_state <= SEND_COMMAND;

						end if;

						m_axis_tvalid <= '0';			-- needed to reset the tvalid when the previous state is the "SEND_DUMMY"

					when SEND_COMMAND => 				

						m_axis_tvalid <= '1';				-- put tvalid = '1' beacuse now we have valid data on tdata bus
						m_axis_tdata  <= CMDSETLEDRGB;		-- send the command to the jstk in order to set the led state 

						if m_axis_tready = '1' then			-- change state only when the axis slave is ready to receive the next data
							
							tx_state <= SEND_LED_R;

						end if;

					when SEND_LED_R =>

						m_axis_tdata  <= led_r;

						if m_axis_tready = '1' then			-- change state only when the axis slave is ready to receive the next data

							tx_state <= SEND_LED_G;

						end if;

					when SEND_LED_G =>

						m_axis_tdata  <= led_g;

						if m_axis_tready = '1' then			-- change state only when the axis slave is ready to receive the next data

							tx_state <= SEND_LED_B;

						end if;

					when SEND_LED_B =>

						m_axis_tdata  <= led_b;

						if m_axis_tready = '1' then			-- change state only when the axis slave is ready to receive the next data

							tx_state <= SEND_DUMMY;

						end if;

					when SEND_DUMMY =>						-- we need to send a 5th dummy byte to the jstk in order to receive correctly the 5th byte of the packet from the jstk (SPI protcol)

						m_axis_tdata <= (Others => '0');

						if m_axis_tready = '1' then			-- change state only when the axis slave is ready to receive the next data

							tx_state <= DELAY;
							
						end if;

				end case;

				-- receiver
				case rx_state is

					when RX_RESET => 

						rx_state <= RECEIVE_JSTK_X_LSB;

					when RECEIVE_JSTK_X_LSB =>

						if s_axis_tvalid = '1' then				-- proceed only if the data we are receving is valid

							jstk_x_reg(jstk_x'HIGH-2 downto 0) <= s_axis_tdata;		-- save the jstk_x LSB
							rx_state <= RECEIVE_JSTK_X_MSB;

						end if;

					when RECEIVE_JSTK_X_MSB =>

						if s_axis_tvalid = '1' then				-- proceed only if the data we are receving is valid

							jstk_x_reg(jstk_x'HIGH downto jstk_x'HIGH-1) <= s_axis_tdata(jstk_x'LOW+1 downto 0);	-- save the jstk_x MSB
							rx_state <= RECEIVE_JSTK_Y_LSB;

						end if;				

					when RECEIVE_JSTK_Y_LSB =>

						if s_axis_tvalid = '1' then				-- proceed only if the data we are receving is valid

							jstk_y_reg(jstk_y'HIGH-2 downto 0) <= s_axis_tdata;		-- save the jstk_y LSB
							rx_state <= RECEIVE_JSTK_Y_MSB;

						end if;

					when RECEIVE_JSTK_Y_MSB =>

						if s_axis_tvalid = '1' then				-- proceed only if the data we are receving is valid

							jstk_y_reg(jstk_y'HIGH downto jstk_y'HIGH-1) <= s_axis_tdata(jstk_y'LOW+1 downto 0);	-- save the jstk_y MSB
							rx_state <= RECEIVE_BUTTONS;

						end if;

					when RECEIVE_BUTTONS =>

						if s_axis_tvalid = '1' then				-- proceed only if the data we are receving is valid

							rx_state <= RECEIVE_JSTK_X_LSB;

							jstk_x 		<= jstk_x_reg;			-- we decided to put the jstk data on the output only in the last state, beacuse they belong to the same packet of bytes
							jstk_y 		<= jstk_y_reg;
							btn_jstk 	<= s_axis_tdata(0);
							btn_trigger <= s_axis_tdata(1);

						end if;

				end case;

			end if;

		end if;

	end process;

end architecture;
