-- ==============================================================
-- FILE : RS232_UART.VHD  -  may be modified by GOLDO
-- ==============================================================
--
-- ==============================================================


library IEEE;
  use IEEE.std_logic_1164.ALL;
  use IEEE.std_logic_arith.ALL;
  use IEEE.std_logic_unsigned.ALL;

--use work.FPGA_CONST.ALL;

entity RS232_UART_ROBOT is
  port (
    -- reset & clock
    RESET               : in  std_logic;
    CLK                 : in  std_logic;
    
    -- internal interface
    DATA_IN             : in std_logic_vector (31 downto 0);
    CSR_IN              : in std_logic_vector (31 downto 0);
    DIVIDER_IN          : in std_logic_vector (31 downto 0);
    DATA_WR             : in std_logic;
    DATA_RD             : in std_logic;
    DATA_OUT            : out std_logic_vector (31 downto 0);
    CSR_OUT             : out std_logic_vector (31 downto 0);
    TX_COUNT_OUT        : out std_logic_vector (31 downto 0);
    RX_COUNT_OUT        : out std_logic_vector (31 downto 0);

    -- rs232 uart lines
    RX                  : in  std_logic;
    TX                  : out std_logic
  );
end RS232_UART_ROBOT;


architecture RTL of RS232_UART_ROBOT is

-- ----------------------------------------------------------------------------
-- Component declarations
-- ----------------------------------------------------------------------------
  component RS232TX
    port (
      RESET     : in  std_logic;
      CLOCK     : in  std_logic;
      BAUD_X_16 : in  std_logic;
      STOP_BITS : in  std_logic_vector(1 downto 0);
      DIN       : in  std_logic_vector(7 downto 0);
      WRITE     : in  std_logic;
      TX        : out std_logic;
      TX_FULL   : out std_logic;
      TX_COUNT  : out std_logic_vector(31 downto 0) );
  end component;

  component RS232RX
    port (
      RESET     : in  std_logic;
      CLOCK     : in  std_logic;
      BAUD_X_16 : in  std_logic;
      READ      : in  std_logic;
      RX        : in  std_logic;
      DOUT      : out std_logic_vector(7 downto 0);
      RX_EMPTY  : out std_logic;
      RX_COUNT  : out std_logic_vector(31 downto 0) );
  end component;

-- ----------------------------------------------------------------------------
-- Constant declarations
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Signal declarations
-- ----------------------------------------------------------------------------

-- Controler side =============================================================

-- RS232 Control/Status register and fields -----------------------------------
--  signal iCSR       : std_logic_vector(31 downto 0);

-- IN : uart speed selector
--  signal iBAUD_SEL  : std_logic_vector(3 downto 0);
    
-- IN : stop bit selector
  signal iSTOP_BITS : std_logic_vector(1 downto 0);

-- OUT : receive queue empty
  signal iRX_EMPTY  : std_logic;
-- OUT : transmit queue full
  signal iTX_FULL   : std_logic;

-- OUT : data in receive queue
  signal iRX_COUNT  : std_logic_vector(31 downto 0);
-- OUT : data in transmit queue
  signal iTX_COUNT  : std_logic_vector(31 downto 0);

-- RS232 side =================================================================
-- DATA PATH CONTROL OUT : READ (RX) command
  signal iREAD      : std_logic;
-- DATA PATH CONTROL OUT : WRITE (TX) command
  signal iWRITE     : std_logic;
    
-- DATA IN 
  signal iDIN       : std_logic_vector(31 downto 0);
-- DATA OUT 
  signal iDOUT      : std_logic_vector(31 downto 0);

-- UART CLOCK generator
  signal iUARTcount : std_logic_vector(11 downto 0);
  signal iUARTtc    : std_logic_vector(11 downto 0);
  signal iUARTen    : std_logic;

begin

-- ----------------------------------------------------------------------------
-- Combinatorial logic
-- ----------------------------------------------------------------------------

-- iCSR register fields (RW)
--iSTOP_BITS  <= iCSR(23 downto 22);
--iBAUD_SEL   <= iCSR(27 downto 24);
iSTOP_BITS  <= "01";

iUARTtc <= DIVIDER_IN(11 downto 0);

-- RX & TX fifo access
iWRITE <= DATA_WR;
iREAD  <= DATA_RD;
iDIN   <= DATA_IN;

DATA_OUT <= iDOUT;

-- iCSR register fields (RO)
-- CSR_OUT <= iCSR;
CSR_OUT <= (16 => iTX_FULL, 17 => iRX_EMPTY, others => '0');

TX_COUNT_OUT <= iTX_COUNT;
RX_COUNT_OUT <= iRX_COUNT;


-------------------------------------------------------------
--
--  Baud Rate    BAUD_SEL
--
--     4800        0000
--     9600        0001
--    19200        0010
--    38400        0011
--    57600        0100
--   115200        0101
--
-- iUARTtc is used to create a pulse at the rate of 16x the Baud Rate.
-- The following values are valid when CLK is running at 50MHz.

--process(iBAUD_SEL)
--begin
--   case iBAUD_SEL is
--    when "0000" => iUARTtc <= "001010001011"; --   4800
--    when "0001" => iUARTtc <= "000101000101"; --   9600
--    when "0010" => iUARTtc <= "000010100011"; --  19200
--    when "0011" => iUARTtc <= "000001010001"; --  38400
--    when "0100" => iUARTtc <= "000000110110"; --  57600
--    when "0101" => iUARTtc <= "000000011011"; -- 115200
--    when "0110" => iUARTtc <= "000000001101"; -- 230400
--    when "0111" => iUARTtc <= "000000000110"; -- 460800
--    when others => iUARTtc <= "000000011011"; -- 115200
--   end case;
--end process;


  -- Count from 0 to iUARTtc. Assert iUARTen for one
  -- CLK cycle during this time.
  process(RESET, CLK)
  begin
    if RESET='1' then
      iUARTcount <= (others=>'0');
    elsif rising_edge(CLK) then
      if (iUARTcount = iUARTtc) then
        iUARTcount <= "000000000000";
      else
        iUARTcount <= iUARTcount + 1;
      end if;
    end if;
  end process;

  iUARTen <= '1' when iUARTcount = "000000000000" else '0';

  -- RS232 Transmitter
  iTX : RS232TX
    port map (
      RESET     => RESET,
      CLOCK     => CLK,
      BAUD_X_16 => iUARTen,
      STOP_BITS => iSTOP_BITS,
      DIN       => iDIN(7 downto 0),
      WRITE     => iWRITE,
      TX        => TX,
      TX_FULL   => iTX_FULL,
      TX_COUNT  => iTX_COUNT );

  -- RS232 Receiver
  iRX : RS232RX
    port map (
      RESET     => RESET,
      CLOCK     => CLK,
      BAUD_X_16 => iUARTen,
      READ      => iREAD,
      RX        => RX,
      DOUT      => iDOUT(7 downto 0),
      RX_EMPTY  => iRX_EMPTY,
      RX_COUNT  => iRX_COUNT );

  iDOUT(30 downto 8) <= (others=>'0');
  iDOUT(31)          <= iRX_EMPTY;

end RTL;
