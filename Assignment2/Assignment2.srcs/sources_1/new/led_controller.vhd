library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity led_controller is
	Generic (
		LED_WIDTH		: positive := 8
	);
	Port (
		mute_enable		: in std_logic;
		filter_enable	: in std_logic;

		led_r			: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_g			: out std_logic_vector(LED_WIDTH-1 downto 0);
		led_b			: out std_logic_vector(LED_WIDTH-1 downto 0)
	);
end led_controller;

architecture Behavioral of led_controller is

begin

	led_r	<= 
		(others => '1') when mute_enable = '1' else		-- when mute enabled, red led on (highest priority)
		(others => '0');

	led_g	<= 
		(others => '1') when mute_enable = '0' and filter_enable = '0' else
		(others => '0');

	led_b	<=
		(others => '1') when mute_enable = '0' and filter_enable = '1' else
		(others => '0');

end Behavioral;