library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_KittCar is
--  Port ( );
end tb_KittCar;

architecture Behavioral of tb_KittCar is
  constant NUM_OF_SWS 	: integer := 4;
  constant NUM_OF_LEDS 	: integer := 4;
  constant TAIL_LENGTH	: integer := 4;
  
  component KittCar is
    Generic (
      -- clk period in nanoseconds (100 MHz)
      CLK_PERIOD_NS			:	POSITIVE	RANGE	1	TO	100;
      -- Minimum step period in milliseconds (i.e., value in milliseconds of DELTA_T)
      MIN_KITT_CAR_STEP_MS	:	POSITIVE	RANGE	1	TO	2000;
      NUM_OF_SWS		:	INTEGER	RANGE	1 TO 16;	-- Number of input switches
      NUM_OF_LEDS		:	INTEGER	RANGE	1 TO 16	-- Number of output
    );
    Port (
      reset	:	IN	STD_LOGIC;
      clk		:	IN	STD_LOGIC;
      sw		:	IN	STD_LOGIC_VECTOR(NUM_OF_SWS-1 downto 0);
      leds	:	OUT	STD_LOGIC_VECTOR(NUM_OF_LEDS-1 downto 0)
    );
  end component;
  
  signal tb_clk    : std_logic                               := '1';
  constant CLK_PER : time                                    := 10ps;
  signal tb_reset  : std_logic                               := '0';
  signal tb_sw     : std_logic_vector(NUM_OF_SWS-1 downto 0) := (Others => '0');
  signal tb_leds   : std_logic_vector(NUM_OF_SWS-1 downto 0) := (Others => '0');
begin


  dut_KittCar : KittCar
    Generic Map(
      CLK_PERIOD_NS			    => 100,        -- 10000 rising edge clk
      MIN_KITT_CAR_STEP_MS	=> 1,          -- 100 / 1 : DELTA_T = 100us
      NUM_OF_SWS		        => NUM_OF_SWS,	
      NUM_OF_LEDS		        => NUM_OF_LEDS
      )
    Port Map(
      clk   => tb_clk,
      reset => tb_reset,
      sw    => tb_sw,
      leds  => tb_leds
    );
  
  tb_clk <= not tb_clk after CLK_PER/2;
  
  sim : process
  begin
    tb_reset <= '1';
    wait for CLK_PER/2;
    
    tb_sw    	<= "0010";
    wait for 10*CLK_PER;
    
    tb_reset 	<= '0';
    wait for 3 * 2*(10**5) * CLK_PER;
    
    tb_sw			<= "0101";
    wait for 4 * 2*(10**5) * CLK_PER;
    
    tb_sw			<= "0001";
    wait for 3 * 2*(10**5) * CLK_PER;
    
    tb_reset 	<= '1';
    wait for 2*CLK_PER;
    
    tb_sw    	<= "1111";
    wait for 2*CLK_PER;
    
    tb_reset 	<= '0';
    wait for 5 * 2*(10**5) * CLK_PER;
    
    assert false report "Failure is a lie! Sei arrivato a fine simulazione, complimenti da Jack" severity FAILURE;

    wait;
  end process sim;

end Behavioral;
