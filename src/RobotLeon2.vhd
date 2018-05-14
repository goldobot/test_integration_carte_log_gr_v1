-- switch configuration
-------+-----+-----+-----+-----+-----------------------------
-- SW5 | SW4 | SW3 | SW2 | SW1 |  comments                  -
-------+-----+-----+-----+-----+-----------------------------
--  X     X     X     X     0  |   normal uart interface
--  X     X     X     X     1  |   invert uart interface between dsu & console
--  X     X     X     0     X  |   use internal i2c eeprom
--  X     X     X     1     X  |   use external i2c eeprom
--  X     X     0     X     X  |   use clock from internal PLL => 13.56
--  X     X     1     X     X  |   use clock from internal PLL => 6.78

library ieee;
use ieee.std_logic_1164.all;
library work;

library unisim;
use unisim.vcomponents.all;

entity RobotLeon2 is
  port(
    n_reset		: in	std_logic
    ; clk		: in	std_logic

    --switch config
    ; sw1		: in	std_logic	--rx/drx+tx/dtx switch
    ; sw2		: in	std_logic	--i2c eprom internal ('0') / external ('1')
    ; sw3		: in	std_logic	--pll cfg0
    ; sw4		: in	std_logic	--pll cfg1
    ; sw5		: in	std_logic	--pll cfg2
    ; sw6		: in	std_logic	--gpio_config(0)
    ; sw7		: in	std_logic	--gpio_config(1)
    ; sw8		: in	std_logic	--gpio_config(2)

    -- uarts
    ; rx		: in	std_logic
    ; tx		: out	std_logic
    ; drx		: in	std_logic
    ; dtx		: out	std_logic

    -- spi
    ; sck		: out	std_logic
    ; mosi		: out	std_logic
    ; miso		: in	std_logic
    ; ssel		: out   std_logic	-- spi slave select

    -- i2c 0
    ; scl0		: inout	std_logic
    ; sda0		: inout	std_logic

    -- debug
    ; leds		: out	std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of RobotLeon2 is


  component BUFGMUX is
    generic (
      CLK_SEL_TYPE : string  := "SYNC"
      );

    port(
      O : out std_ulogic := '0';

      I0 : in std_ulogic := '0';
      I1 : in std_ulogic := '0';
      S  : in std_ulogic := '0'
      );
  end component;


  component core
    port (
      -- system
      n_reset_i	: in	std_logic;
      clk_i		: in	std_logic;
      testmode_i	: in	std_logic;

      -- debug only
      sw1		: in	std_logic;
      sw2		: in	std_logic;

      -- serial interface
      rx		: in	std_logic;
      tx		: out	std_logic;
      drx		: in	std_logic;
      dtx		: out	std_logic;

      -- i2c
      sda0_i		: in	std_logic;
      sda0_o		: out	std_logic;
      sda0_en		: out	std_logic;  -- output when '0'
      scl0_i		: in	std_logic;
      scl0_o		: out	std_logic;
      scl0_en		: out	std_logic;  -- output when '0'

      -- spi
      sck		: out	std_logic;
      mosi		: out	std_logic;
      miso		: in	std_logic;

      -- GPIO
      pad_gpio_i	: in	std_logic_vector(3 downto 0);
      pad_gpio_o	: out	std_logic_vector(3 downto 0);
      pad_gpio_en	: out	std_logic_vector(3 downto 0);
      pad_config	: in	std_logic_vector(10 downto 0);

      -- need for completude
      drx_en		: out	std_logic;
      drx_o		: out	std_logic;
      dtx_en		: out	std_logic;
      dtx_i		: in	std_logic;
      miso_en		: out	std_logic;
      miso_o		: out	std_logic;
      mosi_en		: out	std_logic;
      mosi_i		: in	std_logic;
      rx_en		: out	std_logic;
      rx_o		: out	std_logic;
      sck_en		: out	std_logic;
      sck_i		: in	std_logic;
      tx_en		: out	std_logic;
      tx_i		: in	std_logic
      );
  end component;


  signal clk_pll		: std_logic ;

  signal sda0_i		: std_logic;
  signal sda0_o		: std_logic;
  signal sda0_en		: std_logic;
  signal scl0_i		: std_logic;
  signal scl0_o		: std_logic;
  signal scl0_en		: std_logic;
  signal sda0_ii		: std_logic;
  signal scl0_ii		: std_logic;
  signal eeprom_sda_o	: std_logic;
  signal eeprom_sda_en	: std_logic;
  signal eeprom_scl_o	: std_logic;
  signal eeprom_scl_en	: std_logic;

  signal gpio_in		: std_logic_vector(3 downto 0);
  signal gpio_out		: std_logic_vector(3 downto 0);
  signal gpio_en		: std_logic_vector(3 downto 0);
  signal gpio_config	: std_logic_vector(10 downto 0);

  signal neon_leds	: std_logic_vector(7 downto 0);
  signal led8		: std_logic_vector(7 downto 0);


  signal n_reset_i	: std_logic;
  signal clk_core		: std_logic;

  signal rx1,rx2		: std_logic;
  signal tx1,tx2		: std_logic;

  signal clk_o 		: std_logic;

  signal clk_core_i 	: std_logic;
  signal clk_nfc_gen0	: std_logic;
  signal clk_nfc_gen1	: std_logic;
  signal clk_nfc_gen2	: std_logic;


begin

  -- le switch sw1 est utilis pour inverser les deux liaisons sries
  -- la valeur par dfault est '0' (switch sur off)
  rx1	<= rx when sw1 ='0' else drx;
  rx2	<= drx when sw1 ='0' else rx;
  tx	<= tx1 when sw1 = '0' else tx2;
  dtx	<= tx2 when sw1 = '0' else tx1;


  --buffer in clock
  clk_trf_in_buf : IBUFG
    port map
    (O => clk_o,
     I => clk);	

  --reset management
  n_reset_i <= n_reset;


  --core instantiation
  core_inst : core
    port map(
      n_reset_i	=> n_reset_i
      , clk_i		=> clk_o
      , testmode_i	=> '0'
      , sw1		=> '0'
      , sw2		=> '0'

      -- serial interface
      , rx		=> rx1
      , tx		=> tx1
      , drx		=> rx2
      , dtx		=> tx2

      -- i2c
      , sda0_i	=> sda0_i
      , sda0_o	=> sda0_o
      , sda0_en	=> sda0_en
      , scl0_i	=> scl0_i
      , scl0_o	=> scl0_o
      , scl0_en	=> scl0_en

      -- spi
      , sck		=> sck
      , mosi		=> mosi
      , miso		=> miso
      -- GPIO
      , pad_gpio_i	=> gpio_in
      , pad_gpio_o	=> gpio_out
      , pad_gpio_en	=> gpio_en
      , pad_config	=> gpio_config

      -- need for completude
      , drx_en	=> open
      , drx_o		=> open
      , dtx_en	=> open
      , dtx_i		=> '0'
      , miso_en	=> open
      , miso_o	=> open
      , mosi_en	=> open
      , mosi_i	=> '0'
      , rx_en		=> open
      , rx_o		=> open
      , sck_en	=> open
      , sck_i		=> '0'
      , tx_en		=> open
      , tx_i		=> '0'
      );

  -- i2c mux
  scl0_i <= scl0_ii when sw2 = '0' else scl0;
  sda0_i <= sda0_ii when sw2 = '0' else sda0;

  -- ** external i2c eeprom **
  scl0 <= scl0_o when scl0_en = '0' and sw2 = '1' else 'Z';
  sda0 <= sda0_o when sda0_en = '0' and sw2 = '1' else 'Z';



  -- tristate and pull-up
  process(eeprom_sda_en, eeprom_sda_o, sw2, sda0_en, sda0_o)
  begin
       if sw2 = '0' then
         if eeprom_sda_en = '0' then
           sda0_ii	<= eeprom_sda_o;
         elsif sda0_en = '0' then
           sda0_ii	<= sda0_o;
         else
           sda0_ii	<= '1';
         end if;
       else
           sda0_ii	<= '1';
       end if;
  end process;
  process(eeprom_scl_en, eeprom_scl_o, sw2, scl0_en, scl0_o)
  begin
       if sw2 = '0' then
         if eeprom_scl_en = '0' then
           scl0_ii	<= eeprom_scl_o;
         elsif scl0_en = '0' then
           scl0_ii	<= scl0_o;
         else
           scl0_ii	<= '1';
         end if;
       else
           scl0_ii	<= '1';
       end if;
  end process;

  -- ** GPIO **
  -- GPIO.out
  ssel 	     <= gpio_out(1);	--spi side, slave select
  -- 	     <= gpio_out(2);	--use gpio.in
  neon_leds(0) <= gpio_out(3);	--debug with led... only for FPGA
  --GPIO.in
--	gpio_in(0) <= '0';
  gpio_in(0) <= gpio_out(0);
--	gpio_in(1) <= '0';
  gpio_in(1) <= gpio_out(1);
--	gpio_in(3) <= '0';
  gpio_in(3) <= gpio_out(3);
  --GPIO.config
  gpio_config <= "00000000" & sw8 & sw7 & sw6;

  -- Debug --
  leds_proc : process( n_reset, clk_o )
    variable counter : integer := 0;
  begin
    if ( n_reset = '0' ) then
      led8 <= "00000001";
      counter := 0;
    elsif rising_edge( clk_o ) then
      if ( counter = 16000000 ) then
        led8 <= led8( 6 downto 0 ) & led8( 7 );
        counter := 0;
      else
        counter := counter + 1;
      end if;
    end if;
  end process leds_proc;

  --leds on mainboard
  leds <= not( led8( 6 downto 0 ) ) & neon_leds( 0 );

end architecture rtl;
