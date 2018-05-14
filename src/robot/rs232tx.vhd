-- ==============================================================
-- FILE : RS232TX.VHD  -  may be modified by the USER
-- ==============================================================
--
-- This file is part of the RS-422 Area-scan Camera example, for
-- the HERON-FPGA3 module.
--
-- This file may be modified by the users to implement their
-- own logic.
--
-- ==============================================================
--
--  Module      : RS232TX
--  Date        : 10/07/2002
--  Author      : R. Williams - HUNT ENGINEERING
--  Description : RS232 Transmitter
--
-- ==============================================================
--
--  Ver     Modified By      Date      Changes
--  ---     -----------      ----      -------
--  1.0     R. Williams    10-07-02    First Written
--  2.0     R. Williams    07-11-02    Modified to use new 6-FIFO
--                                     components.
--  2.1     R. Williams    08-11-02    Added Automatic Region-of-
--                                     Interest logic.
--
-- ==============================================================


library IEEE;
  use IEEE.std_logic_1164.ALL;
  use IEEE.std_logic_arith.ALL;
  use IEEE.std_logic_unsigned.ALL;
  use WORK.ALL;


entity RS232TX is
  port (
    RESET     : in  std_logic;
    CLOCK     : in  std_logic;
    BAUD_X_16 : in  std_logic;
    STOP_BITS : in  std_logic_vector(1 downto 0);
    DIN       : in  std_logic_vector(7 downto 0);
    WRITE     : in  std_logic;
    TX        : out std_logic;
    TX_FULL   : out std_logic;
    TX_COUNT  : out std_logic_vector(31 downto 0)
  );
end RS232TX;


architecture Behavioral of RS232TX is

  constant UART_FIFO_DEPTH : integer := 8;

  component uart_fifo IS
    port
    (
      aclr      : in std_logic  := '0';
      clock     : in std_logic ;
      data      : in std_logic_vector (7 downto 0);
      rdreq     : in std_logic ;
      sclr      : in std_logic ;
      wrreq     : in std_logic ;
      empty     : out std_logic ;
      full      : out std_logic ;
      q         : out std_logic_vector (7 downto 0);
      usedw     : out std_logic_vector (UART_FIFO_DEPTH downto 0)
    );
  end component;

  signal TXcount   : std_logic_vector(3 downto 0);
  signal TXsreg    : std_logic_vector(9 downto 0);
  signal TXidle    : std_logic;
  signal TXout     : std_logic;

  signal BITcount  : std_logic_vector(3 downto 0);
  signal STOPcount : std_logic_vector(3 downto 0);

  signal RDREQ     : std_logic;

  signal DATA      : std_logic_vector(7 downto 0);

  signal FIFOempty : std_logic;

  signal MyWaitStates : std_logic_vector(1 downto 0);

  signal iUSEDW    : std_logic_vector(UART_FIFO_DEPTH downto 0);
begin

  TX <= TXout;

  process(RESET, CLOCK)
  begin
    if RESET='1' then
      TXcount <= (others=>'0');
    elsif rising_edge(CLOCK) then
      if BAUD_X_16='1' then
        TXcount <= TXcount + 1;
      end if;
    end if;
  end process;


  process(RESET, CLOCK)
  begin
    if RESET='1' then
      RDREQ    <= '0';
      TXidle   <= '1';
      TXsreg   <= (others=>'1');
      BITcount <= (others=>'0');
      MyWaitStates <= "00";
    elsif rising_edge(CLOCK) then
      RDREQ <= '0';
      if TXidle='1' and FIFOempty='0' and MyWaitStates <= "00" then
        MyWaitStates <= "01";
        TXidle <= '0';
        RDREQ <= '1';
      end if;
      if MyWaitStates="01" then
        MyWaitStates <= "10";
      end if;
      if MyWaitStates="10" then
        MyWaitStates <= "11";
      end if;
      if MyWaitStates="11" and BAUD_X_16='0' then
        TXsreg <= '1' & DATA & '0';
        MyWaitStates <= "00";
      end if;
      if BAUD_X_16='1' and TXcount="1111" then
        TXout  <= TXsreg(0);
        TXsreg <= '1' & TXsreg(9 downto 1);
        if TXidle='0' then
          BITcount <= BITcount + 1;
          if BITcount=STOPcount then
            TXidle <= '1';
            BITcount <= (others=>'0');
          end if;
        end if;
      end if;
    end if;
  end process;

  -- If Stop_Bits="01", 1 stop bit is used
  -- If Stop_Bits="10", 2 stop bits are used
  STOPcount <= "10" & STOP_BITS;

  c_txfifo : uart_fifo
    port map (
      aclr  => RESET,
      clock => CLOCK,
      data  => DIN,
      rdreq => RDREQ,
      sclr  => RESET,
      wrreq => WRITE,
      empty => FIFOempty,
      full  => TX_FULL,
      q     => DATA,
      usedw => iUSEDW
    );

  TX_COUNT(UART_FIFO_DEPTH downto 0) <= iUSEDW;
  TX_COUNT(31 downto UART_FIFO_DEPTH+1) <= (others=>'0');

end Behavioral;
