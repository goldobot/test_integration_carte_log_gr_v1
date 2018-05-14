
library ieee;
use ieee.std_logic_1164.all;
use work.core_pkg.all;

use work.target.all;
use work.config.all;
use work.iface.all;
use work.amba.all;
use work.ambacomp.all;
use work.tech_map.all;


entity core is
  port (
    -- Systeme
    n_reset_i  : in std_logic;
    clk_i      : in std_logic;

    -- serial interface
    rx  : in  std_logic;
    tx  : out std_logic;
    drx : in  std_logic;
    dtx : out std_logic;

    -- i2c master
    i2c_mst_sda_i  : in  std_logic;
    i2c_mst_sda_o  : out std_logic;
    i2c_mst_sda_en : out std_logic;
    i2c_mst_scl_i  : in  std_logic;
    i2c_mst_scl_o  : out std_logic;
    i2c_mst_scl_en : out std_logic;

    -- i2c slave
    i2c_slv_sda_i  : in  std_logic;
    i2c_slv_sda_o  : out std_logic;
    i2c_slv_sda_en : out std_logic;
    i2c_slv_scl_i  : in  std_logic;
    i2c_slv_scl_o  : out std_logic;
    i2c_slv_scl_en : out std_logic;

    -- spi master
    sck  : out std_logic;
    mosi : out std_logic;
    miso : in  std_logic;

    -- spi slave
    slv_cs   : in  std_logic;
    slv_clk  : in  std_logic;
    slv_mosi : in  std_logic;
    slv_miso : out std_logic;

    -- ROBOT
    -- hcsr04 interfaces
    us1_trig            : out std_logic;
    us1_echo            : in std_logic;
    us2_trig            : out std_logic;
    us2_echo            : in std_logic;
    us3_trig            : out std_logic;
    us3_echo            : in std_logic;

    -- misc actuator interfaces
    pwm_servo1          : out std_logic;
    pwm_servo2          : out std_logic;
    pwm_servo3          : out std_logic;
    pwm_magnet1         : out std_logic;
    pwm_magnet2         : out std_logic;

    -- LEDS
    leds        : out std_logic_vector(7 downto 0);

    -- debug/test
    debug_test          : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of core is

  signal clk_m  : std_logic;
  signal clk    : std_logic;
  signal clkn   : std_logic;
  signal rst    : std_logic;
  signal memi   : memory_in_type;
  signal memo   : memory_out_type;
  signal ioi    : io_in_type;
  signal ioo    : io_out_type;
  signal cgi    : clkgen_in_type := ('0', '0', (others => '0'));
  signal cgo    : clkgen_out_type;
  signal iui    : iu_in_type;
  signal iuo    : iu_out_type;
  signal ahbsto : ahbstat_out_type;
  signal mctrlo : mctrl_out_type;
  signal wpo    : wprot_out_type;
  signal apbi   : apb_slv_in_vector(0 to APB_SLV_MAX-1);
  signal apbo   : apb_slv_out_vector(0 to APB_SLV_MAX-1);
  signal ahbmi  : ahb_mst_in_vector(0 to AHB_MST_MAX-1);
  signal ahbmo  : ahb_mst_out_vector(0 to AHB_MST_MAX-1);
  signal ahbsi  : ahb_slv_in_vector(0 to AHB_SLV_MAX-1);
  signal ahbso  : ahb_slv_out_vector(0 to AHB_SLV_MAX);
  signal timo   : timers_out_type;
  signal uart1i : uart_in_type;
  signal uart1o : uart_out_type;

  -- IRQ
  signal i2c_mst_irq     : std_logic;
  signal spi_irq         : std_logic;

  -- mem
  signal data_ram    : std_logic_vector(31 downto 0);
  signal data_rom    : std_logic_vector(31 downto 0);
  signal data_rom0   : std_logic_vector(31 downto 0);
  signal data_rom1   : std_logic_vector(31 downto 0);
  signal rwen        : std_logic_vector(3 downto 0);
  signal romce       : std_logic;
  signal ramce       : std_logic;

  -- periph + IO
  signal s_rx         : std_logic;
  signal s_tx         : std_logic;
  signal s_drx        : std_logic;
  signal s_dtx        : std_logic;
  signal s_i2c_mst_sda_i     : std_logic;
  signal s_i2c_mst_sda_o     : std_logic;
  signal s_i2c_mst_sda_oe    : std_logic;
  signal s_i2c_mst_scl_i     : std_logic;
  signal s_i2c_mst_scl_o     : std_logic;
  signal s_i2c_mst_scl_oe    : std_logic;
  signal s_sck        : std_logic;
  signal s_mosi       : std_logic;
  signal s_miso       : std_logic;

  -- LED
  signal s_leds  : std_logic_vector(7 downto 0);

  component rstgen
    port (
      rstin  : in  std_logic;
      clk    : in  clk_type;
      rstout : out std_logic;
      cgo    : in  clkgen_out_type);
  end component;

  component robot_apb
    port(
        pclk                : in  std_logic
      ; presetn             : in  std_logic
      ; paddr               : in  std_logic_vector(31 downto 0)
      ; psel                : in  std_logic
      ; penable             : in  std_logic
      ; pwrite              : in  std_logic
      ; pwdata              : in  std_logic_vector(31 downto 0)
      ; prdata              : out std_logic_vector(31 downto 0)
      -- hcsr04 interfaces
      ; us1_trig            : out std_logic
      ; us1_echo            : in std_logic
      ; us2_trig            : out std_logic
      ; us2_echo            : in std_logic
      ; us3_trig            : out std_logic
      ; us3_echo            : in std_logic
      -- misc actuator interfaces
      ; pwm_servo1          : out std_logic
      ; pwm_servo2          : out std_logic
      ; pwm_servo3          : out std_logic
      ; pwm_magnet1         : out std_logic
      ; pwm_magnet2         : out std_logic
      -- I2C slave signals
      ; sda_in_slv          : in  std_logic
      ; sda_out_slv         : out std_logic
      ; sda_en_slv          : out std_logic
      ; scl_in_slv          : in  std_logic
      ; scl_out_slv         : out std_logic
      ; scl_en_slv          : out std_logic
      -- SPI slave signals
      ; spi_cs              : in std_logic
      ; spi_clk             : in  std_logic
      ; spi_mosi            : in  std_logic
      ; spi_miso            : out std_logic
      -- debug/test
      ; debug_test          : out std_logic_vector(31 downto 0)
    );
  end component;

  component rom_robot
    port(
        clk     : in  std_logic
      ; address : in  std_logic_vector(27 downto 0)
      ; d       : in  std_logic_vector(31 downto 0)
      ; q       : out std_logic_vector(31 downto 0)
      ; ce      : in  std_logic --active low
      ; we      : in  std_logic_vector(3 downto 0) --active low
    );
  end component;

--  attribute keep_hierarchy : String;
--  attribute keep_hierarchy of rtl : architecture is "yes";

begin

----------------------------------------------------------------------
-- clk, reset generation                                            --
----------------------------------------------------------------------

  -- reset generator
  reset0 : rstgen
    port map (
      rstin  => n_reset_i,
      clk    => clk,
      rstout => rst,
      cgo    => cgo);

  -- clock generator
  clkgen0 : clkgen                      -- tech dependant
    port map (
      clkin => clk_m,
      clk   => clk,
      clkn  => clkn,
      cgo   => cgo);

  -- clock multiplier : Removed
  clk_m <= clk_i;

----------------------------------------------------------------------
-- AHB, APB, VCI bus                                                --
----------------------------------------------------------------------

  -- AHB arbiter/decoder
  ahb0 : ahbarb
    generic map (
      masters => AHB_MASTERS,
      defmast => AHB_DEFMST)
    port map (
      rst  => rst,
      clk  => clk,
      msti => ahbmi(0 to AHB_MASTERS-1),
      msto => ahbmo(0 to AHB_MASTERS-1),
      slvi => ahbsi,
      slvo => ahbso);

  -- AHB/APB bridge
  apb0 : apbmst
    port map (
      rst  => rst,
      clk  => clk,
      ahbi => ahbsi(1),
      ahbo => ahbso(1),
      apbi => apbi,
      apbo => apbo);


-- processor and cache sub-system

----------------------------------------------------------------------
-- Processor, and memory controller                             --
----------------------------------------------------------------------

  proc0 : proc
    port map (
      rst   => rst,
      clk   => clk,
      clkn  => clkn,
      apbi  => apbi(2),
      apbo  => apbo(2),
      ahbi  => ahbmi(0),
      ahbo  => ahbmo(0),
      ahbsi => ahbsi(0),
      iui   => iui,
      iuo   => iuo);


  -- sram/prom/sdram memory controller

  mctrl0 : mctrl
    port map (
      rst    => rst,
      clk    => clk,
      memi   => memi,
      memo   => memo,
      ahbsi  => ahbsi(0),
      ahbso  => ahbso(0),
      apbi   => apbi(0),
      apbo   => apbo(0),
      wpo    => wpo,
      mctrlo => mctrlo);
  wpo.wprothit <= '0';

  ----------------------------------------------------------------------
  -- Other(s) AHB peripheral(s)                                       --
  ----------------------------------------------------------------------

  -- AHB ram

  aram0 : if AHBRAMEN generate
    aram : ahbram generic map (AHBRAM_BITS)
      port map (
        rst   => rst,
        clk   => clk,
        ahbsi => ahbsi(4),
        ahbso => ahbso(4));
  end generate;

  -- AHB status register

  as0 : if AHBSTATEN generate
    asm : ahbstat
      port map (
        rst    => rst,
        clk    => clk,
        ahbmi  => ahbmi(0),
        ahbsi  => ahbsi(0),
        apbi   => apbi(1),
        apbo   => apbo(1),
        ahbsto => ahbsto);
  end generate;

  as1 : if not AHBSTATEN generate
    apbo(1).prdata <= (others => '0'); ahbsto.ahberr <= '0';
  end generate;

----------------------------------------------------------------------
-- APB bus                                                          --
----------------------------------------------------------------------

  -- LEON configuration register
  lc0 : if CFGREG generate
    lcm : lconf
      port map (
        rst  => rst,
        apbo => apbo(4));
  end generate;

  -- Timers (and watchdog)
  timers0 : timers
    port map (
      rst  => rst,
      clk  => clk,
      apbi => apbi(5),
      apbo => apbo(5),
      timo => timo);

  uart1i.rxd                <= s_rx;
  uart1i.ctsn               <= '0';     -- hardware control flow not supported
  -- scaler not used for our purpose, only used when external clocking
  uart1i.scaler(7 downto 4) <= (others => '0');
  uart1i.scaler(2 downto 0) <= (others => '0');
  s_tx                      <= uart1o.txd;

  uart1 : uart
    port map (
      rst   => rst,
      clk   => clk,
      apbi  => apbi(6),
      apbo  => apbo(6),
      uarti => uart1i,
      uarto => uart1o);

-- RIP : irq...
  iui.irl     <= "0000";

-- RIP : parallel I/O port...
--  ioport0 : ioport..

  leds0 : leds_apb
    port map(
      pclk    => clk,
      presetn => rst,
      paddr   => apbi(14).paddr,
      psel    => apbi(14).psel,
      penable => apbi(14).penable,
      pwrite  => apbi(14).pwrite,
      pwdata  => apbi(14).pwdata,
      prdata  => apbo(14).prdata,
      leds    => s_leds);
  
-- FIXME : DEBUG (fsck!) ++
--  i2c0 : i2c_master_top_apb
--    port map (
--      --APB interface
--      clk_i   => clk,
--      rst_i   => rst,
--      apbi    => apbi(22),
--      apbo    => apbo(22),
--      irq     => i2c_mst_irq,
--      --I2C external signals
--      sda_out => s_i2c_mst_sda_o,
--      sda_in  => s_i2c_mst_sda_i,
--      sda_oe  => s_i2c_mst_sda_oe,
--      scl_out => s_i2c_mst_scl_o,
--      scl_in  => s_i2c_mst_scl_i,
--      scl_oe  => s_i2c_mst_scl_oe);
-- FIXME : DEBUG (fsck!) ==
  apbo(22).prdata <= (others => '0');
  i2c_mst_irq <= '0';
  s_i2c_mst_sda_o <= '0';
  s_i2c_mst_sda_oe <= '0';
  s_i2c_mst_scl_o <= '0';
  s_i2c_mst_scl_oe <= '0';
-- FIXME : DEBUG (fsck!) --

-- FIXME : DEBUG (fsck!) ++
--  spi0 : spi_apb
--    port map (
--      clk_i  => clk,
--      rst_i  => rst,
--      apbi   => apbi(25),
--      apbo   => apbo(25),
--      inta_o => spi_irq,
--      -- SPI port
--      sck_o  => s_sck,                  -- serial clock output
--      mosi_o => s_mosi,                 -- MasterOut SlaveIN
--      miso_i => s_miso);                -- MasterIn SlaveOut
-- FIXME : DEBUG (fsck!) ==
  apbo(25).prdata <= (others => '0');
  spi_irq <= '0';
  s_sck <= '0';
  s_miso <= '0';
-- FIXME : DEBUG (fsck!) --

  robot0 : robot_apb
    port map(
      pclk                => clk,
      presetn             => rst,
      paddr               => apbi(27).paddr,
      psel                => apbi(27).psel,
      penable             => apbi(27).penable,
      pwrite              => apbi(27).pwrite,
      pwdata              => apbi(27).pwdata,
      prdata              => apbo(27).prdata,
      -- hcsr04 interfaces
      us1_trig            => us1_trig,
      us1_echo            => us1_echo,
      us2_trig            => us2_trig,
      us2_echo            => us2_echo,
      us3_trig            => us3_trig,
      us3_echo            => us3_echo,
      -- misc actuator interfaces
      pwm_servo1          => pwm_servo1,
      pwm_servo2          => pwm_servo2,
      pwm_servo3          => pwm_servo3,
      pwm_magnet1         => pwm_magnet1,
      pwm_magnet2         => pwm_magnet2,
      -- I2C slave signals
      sda_in_slv          => i2c_slv_sda_i,
      sda_out_slv         => i2c_slv_sda_o,
      sda_en_slv          => i2c_slv_sda_en,
      scl_in_slv          => i2c_slv_scl_i,
      scl_out_slv         => i2c_slv_scl_o,
      scl_en_slv          => i2c_slv_scl_en,
      -- spi slave signals
      spi_cs              => slv_cs,
      spi_clk             => slv_clk,
      spi_mosi            => slv_mosi,
      spi_miso            => slv_miso,
      -- debug/test
      debug_test          => debug_test
      );


-----------------------------
-- Cablage de certaines IO --
-----------------------------

  -- UART 0
  s_rx        <= rx;
  tx          <= s_tx;

  -- UART 1 : (was dsu)
  s_drx       <= drx;
  dtx         <= s_dtx;

  -- I2C 0
  s_i2c_mst_sda_i    <= i2c_mst_sda_i;
  i2c_mst_sda_o      <= s_i2c_mst_sda_o;
  i2c_mst_sda_en     <= not s_i2c_mst_sda_oe; -- active low in I2C master
  s_i2c_mst_scl_i    <= i2c_mst_scl_i;
  i2c_mst_scl_o      <= s_i2c_mst_scl_o;
  i2c_mst_scl_en     <= not s_i2c_mst_scl_oe; -- active low in I2C master

  -- SPI
  sck         <= s_sck;
  mosi        <= s_mosi;
  s_miso      <= miso;


  -- LEDS
  leds        <= s_leds;

  -- FIXME : DEBUG : was DSU connection with uart
  s_dtx <= s_drx;   -- simple loopback for (ex)DSU UART


----------------------------------------------------------------------
-- Memories (used by memory controller)                             --
----------------------------------------------------------------------

----------------------------------------------
-- ROM - 32 Kbytes - 1 waitstate --
----------------------------------------------
  rom_inst : rom32k
    port map(
      clk     => clk,
      address => memo.address,
      d       => memo.data,
      q       => data_rom0,
      ce      => memo.romsn(0),
      we      => memo.wrn);

----------------------------------------------
-- ROM - bootloader routine --
-- Cyclone II EP2C20Q240C8 :
--  without rom_robot_inst : 204800 bits (max 239616 bits)
--  with    rom_robot_inst (256 w) : 212992 bits 
----------------------------------------------
  rom_robot_inst : rom_robot
    port map(
      clk     => clk,
      address => memo.address,
      d       => memo.data,
      q       => data_rom1,
      ce      => memo.romsn(1),
      we      => memo.wrn);

-----------------------------------------------
-- RAM - 64 Kbytes - 1 waitstate --
-----------------------------------------------
  ram_inst64k : ram64k
    port map(
      clk     => clk,
      address => memo.address,
      d       => memo.data,
      q       => data_ram,
      ce      => memo.ramsn(0),
      we      => memo.wrn);

  memi.wrn    <= memo.wrn;
  memi.writen <= memo.writen;
  memi.brdyn  <= '1';
  memi.bexcn  <= '1';
  data_rom    <= data_rom0 when (memo.romsn(0) = '0') else data_rom1;
  memi.data   <= data_ram when memo.ramsn(0) = '0' else data_rom;
  memi.sd     <= (others => '0');

end architecture;
