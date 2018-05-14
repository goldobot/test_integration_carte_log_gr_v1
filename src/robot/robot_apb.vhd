library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

use work.amba.all;
use work.iface.all;

entity robot_apb is
  port(
      pclk                : in  std_logic
    ; presetn             : in  std_logic
    -- APB slave
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
    ; spi_clk             : in std_logic
    ; spi_mosi            : in std_logic
    ; spi_miso            : out std_logic
    -- debug/test
    ; debug_test          : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of robot_apb is

  component ULTRASOUND_HCSR04 is
    port (
      RESET          : in std_logic;
      CLK            : in std_logic; -- the clock should be @ 25MHz
      ACTUAL_DIST    : out std_logic_vector (31 downto 0);
      US_PULSE       : out std_logic;
      US_RESPONSE    : in std_logic
      );
  end component;

  component SERVO is
    port (
      RESET              : in std_logic;
      CLK                : in std_logic;
      PWM_SERVO_PERIOD   : in std_logic_vector (31 downto 0);
      PWM_SERVO_PW       : in std_logic_vector (31 downto 0);
      PWM_SERVO          : out std_logic
      );
  end component;

  component PUMP is
    port (
      RESET              : in std_logic;
      CLK                : in std_logic;
      PWM_PUMP_PERIOD    : in std_logic_vector (31 downto 0);
      PWM_PUMP_PW        : in std_logic_vector (31 downto 0);
      PWM_PUMP           : out std_logic
      );
  end component;

  component robot_i2c_slave is
    port (
      RESET               : in std_logic;
      CLK                 : in std_logic;
      I2C_MASTER_RD       : out std_logic;
      I2C_MASTER_WR       : out std_logic;
      I2C_MASTER_ADDR     : out std_logic_vector(31 downto 0);
      I2C_MASTER_DATA     : out std_logic_vector(31 downto 0);
      I2C_SLAVE_DATA      : in std_logic_vector(31 downto 0);
      I2C_SLAVE_ACK       : in std_logic;
      I2C_SLAVE_IRQ       : out std_logic;
      TRACE_FIFO          : in std_logic_vector(31 downto 0);
      TRACE_FIFO_DEBUG    : out std_logic_vector(31 downto 0);
      TRACE_FIFO_WR       : in std_logic;
      TRACE_FIFO_FULL     : out std_logic;
      TRACE_FIFO_EMPTY    : out std_logic;
      BSTR_FIFO           : out std_logic_vector(31 downto 0);
      BSTR_FIFO_DEBUG     : out std_logic_vector(31 downto 0);
      BSTR_FIFO_RD        : in std_logic;
      BSTR_FIFO_FULL      : out std_logic;
      BSTR_FIFO_EMPTY     : out std_logic;
      SDA_IN              : in     std_logic;
      SDA_OUT             : out    std_logic;
      SDA_EN              : out    std_logic;
      SCL_IN              : in     std_logic;
      SCL_OUT             : out    std_logic;
      SCL_EN              : out    std_logic
    );
  end component;

  component robot_spi_slave is
    port (
      CLK                 : in std_logic;
      RESET               : in std_logic;
      SPI_MASTER_RD       : out std_logic;
      SPI_MASTER_WR       : out std_logic;
      SPI_MASTER_ADDR     : out std_logic_vector(31 downto 0);
      SPI_MASTER_DATA     : out std_logic_vector(31 downto 0);
      SPI_SLAVE_DATA      : in std_logic_vector(31 downto 0);
      SPI_SLAVE_ACK       : in std_logic;
      SPI_SLAVE_IRQ       : out std_logic;
      DBG_MST_DATA        : out std_logic_vector(31 downto 0);
      DBG_SLV_DATA        : in std_logic_vector(31 downto 0);
      SPI_CS              : in std_logic;
      SPI_CLK             : in std_logic;
      SPI_MOSI            : in std_logic;
      SPI_MISO            : out std_logic
    );
  end component;


  signal iRESET               : std_logic;

  signal iROBOT_TIMER         : std_logic_vector (31 downto 0);
  signal iROBOT_RESET         : std_logic_vector (31 downto 0);
  signal iDEBUG_REG           : std_logic_vector (31 downto 0);

  signal iTRACE_FIFO          : std_logic_vector (31 downto 0);
  signal iTRACE_FIFO_DEBUG    : std_logic_vector (31 downto 0);
  signal iTRACE_FIFO_WR       : std_logic;
  signal iTRACE_FIFO_FULL     : std_logic;
  signal iTRACE_FIFO_EMPTY    : std_logic;
  signal iBSTR_FIFO           : std_logic_vector (31 downto 0);
  signal iBSTR_FIFO_DEBUG     : std_logic_vector (31 downto 0);
  signal iBSTR_FIFO_RD        : std_logic;
  signal iBSTR_FIFO_EMPTY     : std_logic;
  signal iBSTR_FIFO_FULL      : std_logic;

  signal iUS1_ACTUAL_DIST     : std_logic_vector (31 downto 0);
  signal iUS2_ACTUAL_DIST     : std_logic_vector (31 downto 0);
  signal iUS3_ACTUAL_DIST     : std_logic_vector (31 downto 0);
  signal iSERVO1_PWM_PERIOD   : std_logic_vector (31 downto 0);
  signal iSERVO1_PW           : std_logic_vector (31 downto 0);
  signal iSERVO2_PWM_PERIOD   : std_logic_vector (31 downto 0);
  signal iSERVO2_PW           : std_logic_vector (31 downto 0);
  signal iSERVO3_PWM_PERIOD   : std_logic_vector (31 downto 0);
  signal iSERVO3_PW           : std_logic_vector (31 downto 0);
  signal iPUMP1_PWM_PERIOD    : std_logic_vector (31 downto 0);
  signal iPUMP1_PW            : std_logic_vector (31 downto 0);
  signal iPUMP2_PWM_PERIOD    : std_logic_vector (31 downto 0);
  signal iPUMP2_PW            : std_logic_vector (31 downto 0);

  signal iI2C_MASTER_RD       : std_logic;
  signal iI2C_MASTER_WR       : std_logic;
  signal iI2C_MASTER_ADDR     : std_logic_vector (31 downto 0);
  signal iI2C_MASTER_DATA     : std_logic_vector (31 downto 0);
  signal iI2C_SLAVE_DATA      : std_logic_vector (31 downto 0);

  signal iMST_READ            : std_logic;
  signal iMST_WRITE           : std_logic;
  signal iMST_ADDR            : std_logic_vector (31 downto 0);
  signal iMST_WDATA           : std_logic_vector (31 downto 0);
  signal iMST_RDATA           : std_logic_vector (31 downto 0);

  signal iSPI_MASTER_RD       : std_logic;
  signal iSPI_MASTER_WR       : std_logic;
  signal iSPI_MASTER_ADDR     : std_logic_vector (31 downto 0);
  signal iSPI_MASTER_DATA     : std_logic_vector (31 downto 0);
  signal iSPI_SLAVE_DATA      : std_logic_vector (31 downto 0);
  signal iSPI_DBG_MST_DATA    : std_logic_vector (31 downto 0);
  signal iSPI_DBG_SLV_DATA    : std_logic_vector (31 downto 0);

begin

  iRESET <= iROBOT_RESET(0) or (not presetn);

  debug_test <= iDEBUG_REG;


-- FIXME : TODO ++
--  c_us1 : ULTRASOUND_HCSR04
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      ACTUAL_DIST => iUS1_ACTUAL_DIST,
--      US_PULSE => us1_trig,
--      US_RESPONSE => us1_echo
--    );
-- FIXME : TODO ==
  us1_trig <= '0';
  iUS1_ACTUAL_DIST <= (others => '0');
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_us2 : ULTRASOUND_HCSR04
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      ACTUAL_DIST => iUS2_ACTUAL_DIST,
--      US_PULSE => us2_trig,
--      US_RESPONSE => us2_echo
--    );
-- FIXME : TODO ==
  us2_trig <= '0';
  iUS2_ACTUAL_DIST <= (others => '0');
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_us3 : ULTRASOUND_HCSR04
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      ACTUAL_DIST => iUS3_ACTUAL_DIST,
--      US_PULSE => us3_trig,
--      US_RESPONSE => us3_echo
--    );
-- FIXME : TODO ==
  us3_trig <= '0';
  iUS3_ACTUAL_DIST <= (others => '0');
-- FIXME : TODO --

-- FIXME : TODO ++
  c_servo1 : SERVO
    port map (
      RESET => iRESET,
      CLK => pclk,
      PWM_SERVO_PERIOD => iSERVO1_PWM_PERIOD,
      PWM_SERVO_PW => iSERVO1_PW,
      PWM_SERVO => pwm_servo1
    );
-- FIXME : TODO ==
--  pwm_servo1 <= '0';
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_servo2 : SERVO
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      PWM_SERVO_PERIOD => iSERVO2_PWM_PERIOD,
--      PWM_SERVO_PW => iSERVO2_PW,
--      PWM_SERVO => pwm_servo2
--    );
-- FIXME : TODO ==
  pwm_servo2 <= '0';
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_servo3 : SERVO
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      PWM_SERVO_PERIOD => iSERVO3_PWM_PERIOD,
--      PWM_SERVO_PW => iSERVO3_PW,
--      PWM_SERVO => pwm_servo3
--    );
-- FIXME : TODO ==
  pwm_servo3 <= '0';
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_pump1 : PUMP
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      PWM_PUMP_PERIOD => iPUMP1_PWM_PERIOD,
--      PWM_PUMP_PW => iPUMP1_PW,
--      PWM_PUMP => pwm_magnet1
--    );
-- FIXME : TODO ==
  pwm_magnet1 <= '0';
-- FIXME : TODO --

-- FIXME : TODO ++
--  c_pump2 : PUMP
--    port map (
--      RESET => iRESET,
--      CLK => pclk,
--      PWM_PUMP_PERIOD => iPUMP2_PWM_PERIOD,
--      PWM_PUMP_PW => iPUMP2_PW,
--      PWM_PUMP => pwm_magnet2
--    );
-- FIXME : TODO ==
  pwm_magnet2 <= '0';
-- FIXME : TODO --

  c_robot_spi_slave : ROBOT_SPI_SLAVE
    port map (
      CLK => pclk,
      RESET => iRESET,
      SPI_MASTER_RD => iSPI_MASTER_RD,
      SPI_MASTER_WR => iSPI_MASTER_WR,
      SPI_MASTER_ADDR => iSPI_MASTER_ADDR,
      SPI_MASTER_DATA => iSPI_MASTER_DATA,
      SPI_SLAVE_DATA => iSPI_SLAVE_DATA,
      SPI_SLAVE_ACK => '1',
      SPI_SLAVE_IRQ => open,
      DBG_MST_DATA => iSPI_DBG_MST_DATA,
      DBG_SLV_DATA => iSPI_DBG_SLV_DATA,
      SPI_CS => spi_cs,
      SPI_CLK => spi_clk,
      SPI_MOSI => spi_mosi,
      SPI_MISO => spi_miso
      );

  c_robot_i2c_slave : robot_i2c_slave
    port map (
      RESET => iRESET,
      CLK => pclk,
      -- generic internal interface 
      I2C_MASTER_RD => iI2C_MASTER_RD,
      I2C_MASTER_WR => iI2C_MASTER_WR,
      I2C_MASTER_ADDR => iI2C_MASTER_ADDR,
      I2C_MASTER_DATA => iI2C_MASTER_DATA,
      I2C_SLAVE_DATA => iI2C_SLAVE_DATA,
      I2C_SLAVE_ACK => '1', -- FIXME : TODO
      I2C_SLAVE_IRQ => open, -- FIXME : TODO
      -- trace fifo
      TRACE_FIFO => iTRACE_FIFO,
      TRACE_FIFO_DEBUG => iTRACE_FIFO_DEBUG,
      TRACE_FIFO_WR => iTRACE_FIFO_WR,
      TRACE_FIFO_FULL => iTRACE_FIFO_FULL,
      TRACE_FIFO_EMPTY => iTRACE_FIFO_EMPTY,
      -- bitstream fifo
      BSTR_FIFO => iBSTR_FIFO,
      BSTR_FIFO_DEBUG => iBSTR_FIFO_DEBUG,
      BSTR_FIFO_RD => iBSTR_FIFO_RD,
      BSTR_FIFO_FULL => iBSTR_FIFO_FULL,
      BSTR_FIFO_EMPTY => iBSTR_FIFO_EMPTY,
      -- I2C (external) interface
      SDA_IN => sda_in_slv,
      SDA_OUT => sda_out_slv,
      SDA_EN => sda_en_slv,
      SCL_IN => scl_in_slv,
      SCL_OUT => scl_out_slv,
      SCL_EN => scl_en_slv
    );


-- timer process
  timer_proc : process (iRESET, pclk)
    variable local_counter : integer := 0;
  begin
    if iRESET = '1' then
      iROBOT_TIMER <= (others => '0');
      local_counter := 0;
    elsif rising_edge(pclk) then
      if ( local_counter = 24 ) then
        iROBOT_TIMER <= iROBOT_TIMER + 1;
        local_counter := 0;
      else
        local_counter := local_counter + 1;
      end if;
    end if;
  end process;
  

---- Multiplexeur pour les 3 interfaces master : APB, I2C et SPI
--  iMST_READ  <= '1' when (((psel='1') and (penable='1') and (pwrite='0')) or
--                (iI2C_MASTER_RD='1') or (iSPI_MASTER_RD='1')) else '0';
--  iMST_WRITE <= '1' when (((psel='1') and (penable='1') and (pwrite='1')) or
--                (iI2C_MASTER_WR='1') or (iSPI_MASTER_WR='1')) else '0';
--  iMST_ADDR  <= paddr when ((psel='1') and (penable='1')) else
--                iSPI_MASTER_ADDR when (iDEBUG_REG(31) = '1') else
--                iI2C_MASTER_ADDR;
--  iMST_WDATA <= pwdata when ((psel='1') and (penable='1') and (pwrite='1')) else
--                iSPI_MASTER_DATA when (iDEBUG_REG(31) = '1') else
--                iI2C_MASTER_DATA;
--  prdata          <= iMST_RDATA;
--  iI2C_SLAVE_DATA <= iMST_RDATA;
--  iSPI_SLAVE_DATA <= iMST_RDATA;

-- Multiplexeur pour les 2 interfaces master : APB et SPI
  iMST_READ  <= '1' when (((psel='1') and (penable='1') and (pwrite='0')) or
                (iSPI_MASTER_RD='1')) else '0';
  iMST_WRITE <= '1' when (((psel='1') and (penable='1') and (pwrite='1')) or
                (iSPI_MASTER_WR='1')) else '0';
  iMST_ADDR  <= paddr when ((psel='1') and (penable='1')) else
                iSPI_MASTER_ADDR;
  iMST_WDATA <= pwdata when ((psel='1') and (penable='1') and (pwrite='1')) else
                iSPI_MASTER_DATA;
  prdata          <= iMST_RDATA;
  iSPI_SLAVE_DATA <= iMST_RDATA;

-- APB Write process
  write_proc : process (presetn, pclk)
  begin
    if presetn = '0' then
      iROBOT_RESET       <= (others => '0');

      iDEBUG_REG         <= X"00000042";

      iSERVO1_PWM_PERIOD <= X"00040000";
      iSERVO1_PW         <= (others => '0');
      iSERVO2_PWM_PERIOD <= X"00040000";
      iSERVO2_PW         <= (others => '0');
      iSERVO3_PWM_PERIOD <= X"00040000";
      iSERVO3_PW         <= (others => '0');
      iPUMP1_PWM_PERIOD  <= X"00000200";
      iPUMP1_PW          <= (others => '0');
      iPUMP2_PWM_PERIOD  <= X"00000200";
      iPUMP2_PW          <= (others => '0');

      iTRACE_FIFO        <= (others => '0');
      iTRACE_FIFO_WR     <= '0';

-- FIXME : DEBUG ++
      iSPI_DBG_SLV_DATA  <= (others => '0');
-- FIXME : DEBUG --

    elsif rising_edge(pclk) then
      if (iMST_WRITE = '1') then
        case iMST_ADDR(11 downto 2) is
          -- timer & reset
          when "0000000000" => -- 0x80008000 -- robot_reg[0x00]
            null;
          when "0000000001" => -- 0x80008004 -- robot_reg[0x01]
            iROBOT_RESET <= iMST_WDATA;
          when "0000000010" => -- 0x80008008 -- robot_reg[0x02]
            iDEBUG_REG <= iMST_WDATA;
          when "0000000011" => -- 0x8000800c -- robot_reg[0x03]
            null;

          -- was uart test in 2016
          when "0000000100" => -- 0x80008010 -- robot_reg[0x04]
            null; -- <available>
          when "0000000101" => -- 0x80008014 -- robot_reg[0x05]
            null; -- <available>
          when "0000000110" => -- 0x80008018 -- robot_reg[0x06]
            null; -- <available>
          when "0000000111" => -- 0x8000801c -- robot_reg[0x07]
            null; -- <available>

          -- i2c slave
          when "0000001000" => -- 0x80008020 -- robot_reg[0x08]
            null; -- FIXME : TODO : control (from APB)
          when "0000001001" => -- 0x80008024 -- robot_reg[0x09]
            null; -- status (from I2C master)
          when "0000001010" => -- 0x80008028 -- robot_reg[0x0a]
            null; -- ADDR from I2C master
          when "0000001011" => -- 0x8000802c -- robot_reg[0x0b]
            null; -- FIXME : TODO : DATA from APB
          when "0000001100" => -- 0x80008030 -- robot_reg[0x0c]
            null; -- FIXME : TODO : TRACE control
          when "0000001101" => -- 0x80008034 -- robot_reg[0x0d]
            iTRACE_FIFO <= iMST_WDATA; -- TRACE FIFO wr
            iTRACE_FIFO_WR <= '1';
          when "0000001110" => -- 0x80008038 -- robot_reg[0x0e]
            null; -- FIXME : TODO : BSTR control
          when "0000001111" => -- 0x8000803c -- robot_reg[0x0f]
            null; -- BSTR read-only for APB

          -- was motors in 2016
          when "0001000000" => -- 0x80008100 -- robot_reg[0x40]
            null; -- <available>
          when "0001001000" => -- 0x80008120 -- robot_reg[0x48]
            null; -- <available>

          -- was odometry in 2016
          when "0010000001" => -- 0x80008204 -- robot_reg[0x81]
            null; -- <available>
          when "0010000011" => -- 0x8000820c -- robot_reg[0x83]
            null; -- <available>
          when "0010000100" => -- 0x80008210 -- robot_reg[0x84]
            null; -- <available>
          when "0010000111" => -- 0x8000821c -- robot_reg[0x87]
            null; -- <available>
          when "0010001001" => -- 0x80008224 -- robot_reg[0x89]
            null; -- <available>
          when "0010001011" => -- 0x8000822c -- robot_reg[0x8b]
            null; -- <available>
          when "0010001100" => -- 0x80008230 -- robot_reg[0x8c]
            null; -- <available>
          when "0010001111" => -- 0x8000823c -- robot_reg[0x8f]
            null; -- <available>

          -- was "advanced" odometry in 2016
          when "0010010001" => -- 0x80008244 -- robot_reg[0x91]
            null; -- <available>
          when "0010010011" => -- 0x8000824c -- robot_reg[0x93]
            null; -- <available>
          when "0010010100" => -- 0x80008250 -- robot_reg[0x94]
            null; -- <available>
          when "0010010111" => -- 0x8000825c -- robot_reg[0x97]
            null; -- <available>
          when "0010011001" => -- 0x80008264 -- robot_reg[0x99]
            null; -- <available>
          when "0010011011" => -- 0x8000826c -- robot_reg[0x9b]
            null; -- <available>
          when "0010011100" => -- 0x80008270 -- robot_reg[0x9c]
            null; -- <available>
          when "0010011111" => -- 0x8000827c -- robot_reg[0x9f]
            null; -- <available>

          when "0010100001" => -- 0x80008284 -- robot_reg[0xa1]
            null; -- <available>
          when "0010100011" => -- 0x8000828c -- robot_reg[0xa3]
            null; -- <available>
          when "0010100100" => -- 0x80008290 -- robot_reg[0xa4]
            null; -- <available>
          when "0010100111" => -- 0x8000829c -- robot_reg[0xa7]
            null; -- <available>
          when "0010101001" => -- 0x800082a4 -- robot_reg[0xa9]
            null; -- <available>
          when "0010101011" => -- 0x800082ac -- robot_reg[0xab]
            null; -- <available>
          when "0010101100" => -- 0x800082b0 -- robot_reg[0xac]
            null; -- <available>
          when "0010101111" => -- 0x800082bc -- robot_reg[0xaf]
            null; -- <available>

          -- was 64bit multiplier in 2016
          when "0010110000" => -- 0x800082c0 -- robot_reg[0xb0]
            null; -- <available>
          when "0010110001" => -- 0x800082c4 -- robot_reg[0xb1]
            null; -- <available>
          when "0010110010" => -- 0x800082c8 -- robot_reg[0xb2]
            null; -- <available>
          when "0010110011" => -- 0x800082cc -- robot_reg[0xb3]
            null; -- <available>

          -- was sin_cos in 2016
          when "0010111000" => -- 0x800082e0 -- robot_reg[0xb8]
            null; -- <available>
          when "0010111001" => -- 0x800082e4 -- robot_reg[0xb9]
            null; -- <available>
          when "0010111010" => -- 0x800082e8 -- robot_reg[0xba]
            null; -- <available>
          when "0010111011" => -- 0x800082ec -- robot_reg[0xbb]
            null; -- <available>

          -- PETIT ROBOT 2018
          when "0011000000" => -- 0x80008300 -- robot_reg[0xc0]
            null; -- iUS1_ACTUAL_DIST
          when "0011000001" => -- 0x80008304 -- robot_reg[0xc1]
            null; -- iUS2_ACTUAL_DIST
          when "0011000010" => -- 0x80008308 -- robot_reg[0xc2]
            null; -- iUS3_ACTUAL_DIST
          when "0011000011" => -- 0x8000830c -- robot_reg[0xc3]
            null; -- <available>
          when "0011000100" => -- 0x80008310 -- robot_reg[0xc4]
            iSERVO1_PWM_PERIOD <= iMST_WDATA;
          when "0011000101" => -- 0x80008314 -- robot_reg[0xc5]
            iSERVO1_PW         <= iMST_WDATA;
          when "0011000110" => -- 0x80008318 -- robot_reg[0xc6]
            iSERVO2_PWM_PERIOD <= iMST_WDATA;
          when "0011000111" => -- 0x8000831c -- robot_reg[0xc7]
            iSERVO2_PW         <= iMST_WDATA;
          when "0011001000" => -- 0x80008320 -- robot_reg[0xc8]
            iSERVO3_PWM_PERIOD <= iMST_WDATA;
          when "0011001001" => -- 0x80008324 -- robot_reg[0xc9]
            iSERVO3_PW         <= iMST_WDATA;
          when "0011001010" => -- 0x80008328 -- robot_reg[0xca]
            null; -- <available>
          when "0011001011" => -- 0x8000832c -- robot_reg[0xcb]
            null; -- <available>
          when "0011001100" => -- 0x80008330 -- robot_reg[0xcc]
            iPUMP1_PWM_PERIOD <= iMST_WDATA;
          when "0011001101" => -- 0x80008334 -- robot_reg[0xcd]
            iPUMP1_PW         <= iMST_WDATA;
          when "0011001110" => -- 0x80008338 -- robot_reg[0xce]
            iPUMP2_PWM_PERIOD <= iMST_WDATA;
          when "0011001111" => -- 0x8000833c -- robot_reg[0xcf]
            iPUMP2_PW         <= iMST_WDATA;

          -- was GPS in 2016
          when "0011010000" => -- 0x80008340 -- robot_reg[0xd0]
            null; -- <available>
          when "0011010001" => -- 0x80008344 -- robot_reg[0xd1]
            null; -- <available>
          when "0011010010" => -- 0x80008348 -- robot_reg[0xd2]
            null; -- <available>
          when "0011010011" => -- 0x8000834c -- robot_reg[0xd3]
            null; -- <available>
          when "0011010100" => -- 0x80008350 -- robot_reg[0xd4]
            null; -- <available>
          when "0011010101" => -- 0x80008354 -- robot_reg[0xd5]
            null; -- <available>
          when "0011010110" => -- 0x80008358 -- robot_reg[0xd6]
            null; -- <available>
          when "0011010111" => -- 0x8000835c -- robot_reg[0xd7]
            null; -- <available>

          -- ROBOT_SPI_SLAVE : esclave SPI
          when "0011011000" => -- 0x80008360 -- robot_reg[0xd8]
            iSPI_DBG_SLV_DATA <= iMST_WDATA;
          when "0011011001" => -- 0x80008364 -- robot_reg[0xd9]
            null; -- <available> -- iSPI_DBG_MST_DATA
          when "0011011010" => -- 0x80008368 -- robot_reg[0xda]
            null; -- <available>
          when "0011011011" => -- 0x8000836c -- robot_reg[0xdb]
            null; -- <available>
          when "0011011100" => -- 0x80008370 -- robot_reg[0xdc]
            null; -- <available>
          when "0011011101" => -- 0x80008374 -- robot_reg[0xdd]
            null; -- <available>
          when "0011011110" => -- 0x80008378 -- robot_reg[0xde]
            null; -- <available>
          when "0011011111" => -- 0x8000837c -- robot_reg[0xdf]
            null; -- <available>

          when others =>
        end case;
      else

        iTRACE_FIFO_WR <= '0';

      end if;
    end if;
  end process;
  
-- APB Read process
  read_proc : process(presetn, iMST_READ)
  begin
    if presetn = '0' then
      iMST_RDATA <= (others => '1');
      iBSTR_FIFO_RD <= '0';
      iBSTR_FIFO_DEBUG <= (others => '0');
    elsif (iMST_READ = '1') then
      case iMST_ADDR(11 downto 2) is
        -- timer & reset
        when "0000000000" => -- 0x80008000 -- robot_reg[0x00]
          iMST_RDATA <= iROBOT_TIMER;
        when "0000000001" => -- 0x80008004 -- robot_reg[0x01]
          -- FIXME : TODO : GPIO 2018
--          iMST_RDATA <= (others => '0');
          -- FIXME : DEBUG : SPI
          iMST_RDATA <= iSPI_MASTER_ADDR;
        when "0000000010" => -- 0x80008008 -- robot_reg[0x02]
          iMST_RDATA <= iDEBUG_REG;
        when "0000000011" => -- 0x8000800c -- robot_reg[0x03]
          iMST_RDATA <= X"54455354"; -- 'TEST' TAG

        -- was uart test in 2016
        when "0000000100" => -- 0x80008010 -- robot_reg[0x04]
          iMST_RDATA <= (others => '0');
        when "0000000101" => -- 0x80008014 -- robot_reg[0x05]
          iMST_RDATA <= (others => '0');
        when "0000000110" => -- 0x80008018 -- robot_reg[0x06]
          iMST_RDATA <= (others => '0');
        when "0000000111" => -- 0x8000801c -- robot_reg[0x07]
          iMST_RDATA <= (others => '0');

        -- i2c slave
        when "0000001000" => -- 0x80008020 -- robot_reg[0x08]
          -- FIXME : TODO : control (from APB)
          iMST_RDATA <= (others => '0');
        when "0000001001" => -- 0x80008024 -- robot_reg[0x09]
          -- FIXME : TODO : status (from I2C master)
          iMST_RDATA <= (others => '0');
        when "0000001010" => -- 0x80008028 -- robot_reg[0x0a]
          -- FIXME : TODO : ADDR from I2C master
          iMST_RDATA <= (others => '0');
        when "0000001011" => -- 0x8000802c -- robot_reg[0x0b]
          -- FIXME : TODO : DATA from I2C master
          iMST_RDATA <= (others => '0');
        when "0000001100" => -- 0x80008030 -- robot_reg[0x0c] -- TRACE status
          iMST_RDATA <= X"0000000"&"00"&iTRACE_FIFO_EMPTY&iTRACE_FIFO_FULL;
        when "0000001101" => -- 0x80008034 -- robot_reg[0x0d]
          iMST_RDATA <= iTRACE_FIFO_DEBUG; -- TRACE write-only for APB
        when "0000001110" => -- 0x80008038 -- robot_reg[0x0e] -- BSTR status
          iMST_RDATA <= X"0000000" & "00" & iBSTR_FIFO_EMPTY & iBSTR_FIFO_FULL;
          iBSTR_FIFO_RD <= '0'; -- FIXME : TODO : refactoring (crap!..)
        when "0000001111" => -- 0x8000803c -- robot_reg[0x0f] -- BSTR FIFO rd
          iMST_RDATA <= iBSTR_FIFO;
          iBSTR_FIFO_RD <= '1';

        -- was motors in 2016
        when "0001000000" => -- 0x80008100 -- robot_reg[0x40]
          iMST_RDATA <= (others => '0');
        when "0001001000" => -- 0x80008120 -- robot_reg[0x48]
          iMST_RDATA <= (others => '0');

        -- was odometry in 2016
        when "0010000001" => -- 0x80008204 -- robot_reg[0x81]
          iMST_RDATA <= (others => '0');
        when "0010000011" => -- 0x8000820c -- robot_reg[0x83]
          iMST_RDATA <= (others => '0');
        when "0010000100" => -- 0x80008210 -- robot_reg[0x84]
          iMST_RDATA <= (others => '0');
        when "0010000111" => -- 0x8000821c -- robot_reg[0x87]
          iMST_RDATA <= (others => '0');
        when "0010001001" => -- 0x80008224 -- robot_reg[0x89]
          iMST_RDATA <= (others => '0');
        when "0010001011" => -- 0x8000822c -- robot_reg[0x8b]
          iMST_RDATA <= (others => '0');
        when "0010001100" => -- 0x80008230 -- robot_reg[0x8c]
          iMST_RDATA <= (others => '0');
        when "0010001111" => -- 0x8000823c -- robot_reg[0x8f]
          iMST_RDATA <= (others => '0');

        -- was "advanced" odometry in 2016
        when "0010010001" => -- 0x80008244 -- robot_reg[0x91]
          iMST_RDATA <= (others => '0');
        when "0010010010" => -- 0x80008248 -- robot_reg[0x92]
          iMST_RDATA <= (others => '0');
        when "0010010011" => -- 0x8000824c -- robot_reg[0x93]
          iMST_RDATA <= (others => '0');
        when "0010010100" => -- 0x80008250 -- robot_reg[0x94]
          iMST_RDATA <= (others => '0');
        when "0010010111" => -- 0x8000825c -- robot_reg[0x97]
          iMST_RDATA <= (others => '0');
        when "0010011001" => -- 0x80008264 -- robot_reg[0x99]
          iMST_RDATA <= (others => '0');
        when "0010011010" => -- 0x80008268 -- robot_reg[0x9a]
          iMST_RDATA <= (others => '0');
        when "0010011011" => -- 0x8000826c -- robot_reg[0x9b]
          iMST_RDATA <= (others => '0');
        when "0010011100" => -- 0x80008270 -- robot_reg[0x9c]
          iMST_RDATA <= (others => '0');
        when "0010011111" => -- 0x8000827c -- robot_reg[0x9f]
          iMST_RDATA <= (others => '0');

        -- was "advanced" odometry in 2016
        when "0010100001" => -- 0x80008284 -- robot_reg[0xa1]
          iMST_RDATA <= (others => '0');
        when "0010100010" => -- 0x80008288 -- robot_reg[0xa2]
          iMST_RDATA <= (others => '0');
        when "0010100011" => -- 0x8000828c -- robot_reg[0xa3]
          iMST_RDATA <= (others => '0');
        when "0010100100" => -- 0x80008290 -- robot_reg[0xa4]
          iMST_RDATA <= (others => '0');
        when "0010100111" => -- 0x8000829c -- robot_reg[0xa7]
          iMST_RDATA <= (others => '0');
        when "0010101001" => -- 0x800082a4 -- robot_reg[0xa9]
          iMST_RDATA <= (others => '0');
        when "0010101010" => -- 0x800082a8 -- robot_reg[0xaa]
          iMST_RDATA <= (others => '0');
        when "0010101011" => -- 0x800082ac -- robot_reg[0xab]
          iMST_RDATA <= (others => '0');
        when "0010101100" => -- 0x800082b0 -- robot_reg[0xac]
          iMST_RDATA <= (others => '0');
        when "0010101111" => -- 0x800082bc -- robot_reg[0xaf]
          iMST_RDATA <= (others => '0');

        -- was 64bit multiplier in 2016
        when "0010110000" => -- 0x800082c0 -- robot_reg[0xb0]
          iMST_RDATA <= (others => '0');
        when "0010110001" => -- 0x800082c4 -- robot_reg[0xb1]
          iMST_RDATA <= (others => '0');
        when "0010110010" => -- 0x800082c8 -- robot_reg[0xb2]
          iMST_RDATA <= (others => '0');
        when "0010110011" => -- 0x800082cc -- robot_reg[0xb3]
          iMST_RDATA <= (others => '0');
        when "0010110100" => -- 0x800082d0 -- robot_reg[0xb4]
          iMST_RDATA <= (others => '0');
        when "0010110101" => -- 0x800082d4 -- robot_reg[0xb5]
          iMST_RDATA <= (others => '0');

        -- was sin_cos in 2016
        when "0010111000" => -- 0x800082e0 -- robot_reg[0xb8]
          iMST_RDATA <= (others => '0');
        when "0010111001" => -- 0x800082e4 -- robot_reg[0xb9]
          iMST_RDATA <= (others => '0');
        when "0010111010" => -- 0x800082e8 -- robot_reg[0xba]
          iMST_RDATA <= (others => '0');
        when "0010111011" => -- 0x800082ec -- robot_reg[0xbb]
          iMST_RDATA <= (others => '0');
        when "0010111100" => -- 0x800082f0 -- robot_reg[0xbc]
          iMST_RDATA <= (others => '0');
        when "0010111101" => -- 0x800082f4 -- robot_reg[0xbd]
          iMST_RDATA <= (others => '0');

        -- PETIT ROBOT 2018
        when "0011000000" => -- 0x80008300 -- robot_reg[0xc0]
          iMST_RDATA <= iUS1_ACTUAL_DIST;
        when "0011000001" => -- 0x80008304 -- robot_reg[0xc1]
          iMST_RDATA <= iUS2_ACTUAL_DIST;
        when "0011000010" => -- 0x80008308 -- robot_reg[0xc2]
          iMST_RDATA <= iUS3_ACTUAL_DIST;
        when "0011000011" => -- 0x8000830c -- robot_reg[0xc3]
          iMST_RDATA <= (others => '0');
        when "0011000100" => -- 0x80008310 -- robot_reg[0xc4]
          iMST_RDATA <= iSERVO1_PWM_PERIOD;
        when "0011000101" => -- 0x80008314 -- robot_reg[0xc5]
          iMST_RDATA <= iSERVO1_PW;
        when "0011000110" => -- 0x80008318 -- robot_reg[0xc6]
          iMST_RDATA <= iSERVO2_PWM_PERIOD;
        when "0011000111" => -- 0x8000831c -- robot_reg[0xc7]
          iMST_RDATA <= iSERVO2_PW;
        when "0011001000" => -- 0x80008320 -- robot_reg[0xc8]
          iMST_RDATA <= iSERVO3_PWM_PERIOD;
        when "0011001001" => -- 0x80008324 -- robot_reg[0xc9]
          iMST_RDATA <= iSERVO3_PW;
        when "0011001010" => -- 0x80008328 -- robot_reg[0xca]
          iMST_RDATA <= (others => '0');
        when "0011001011" => -- 0x8000832c -- robot_reg[0xcb]
          iMST_RDATA <= (others => '0');
        when "0011001100" => -- 0x80008330 -- robot_reg[0xcc]
          iMST_RDATA <= iPUMP1_PWM_PERIOD;
        when "0011001101" => -- 0x80008334 -- robot_reg[0xcd]
          iMST_RDATA <= iPUMP1_PW;
        when "0011001110" => -- 0x80008338 -- robot_reg[0xce]
          iMST_RDATA <= iPUMP2_PWM_PERIOD;
        when "0011001111" => -- 0x8000833c -- robot_reg[0xcf]
          iMST_RDATA <= iPUMP2_PW;

        -- was gps in 2016
        when "0011010000" => -- 0x80008340 -- robot_reg[0xd0]
          iMST_RDATA <= (others => '0');
        when "0011010001" => -- 0x80008344 -- robot_reg[0xd1]
          iMST_RDATA <= (others => '0');
        when "0011010010" => -- 0x80008348 -- robot_reg[0xd2]
          iMST_RDATA <= (others => '0');
        when "0011010011" => -- 0x8000834c -- robot_reg[0xd3]
          iMST_RDATA <= (others => '0');
        when "0011010100" => -- 0x80008350 -- robot_reg[0xd4]
          iMST_RDATA <= (others => '0');
        when "0011010101" => -- 0x80008354 -- robot_reg[0xd5]
          iMST_RDATA <= (others => '0');
        when "0011010110" => -- 0x80008358 -- robot_reg[0xd6]
          iMST_RDATA <= (others => '0');
        when "0011010111" => -- 0x8000835c -- robot_reg[0xd7]
          iMST_RDATA <= (others => '0');

        -- ROBOT_SPI_SLAVE : esclave SPI
        when "0011011000" => -- 0x80008360 -- robot_reg[0xd8]
          iMST_RDATA <= iSPI_DBG_SLV_DATA;
        when "0011011001" => -- 0x80008364 -- robot_reg[0xd9]
          iMST_RDATA <= iSPI_DBG_MST_DATA;
        when "0011011010" => -- 0x80008368 -- robot_reg[0xda]
          iMST_RDATA <= (others => '0');
        when "0011011011" => -- 0x8000836c -- robot_reg[0xdb]
          iMST_RDATA <= (others => '0');
        when "0011011100" => -- 0x80008370 -- robot_reg[0xdc]
          iMST_RDATA <= (others => '0');
        when "0011011101" => -- 0x80008374 -- robot_reg[0xdd]
          iMST_RDATA <= (others => '0');
        when "0011011110" => -- 0x80008378 -- robot_reg[0xde]
          iMST_RDATA <= (others => '0');
        when "0011011111" => -- 0x8000837c -- robot_reg[0xdf]
          iMST_RDATA <= (others => '0');

        when others =>
      end case;
    else
      iMST_RDATA <= (others => '1');
      iBSTR_FIFO_RD <= '0';
    end if;
  end process;

end architecture;
