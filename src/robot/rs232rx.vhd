-- ==============================================================
-- FILE : RS232RX.VHD  -  may be modified by the USER
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
--  Module      : RS232RX
--  Date        : 10/07/2002
--  Author      : R. Williams - HUNT ENGINEERING
--  Description : RS232 Receiver
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


entity RS232RX is
  port (
    RESET     : in  std_logic;
    CLOCK     : in  std_logic;
    BAUD_X_16 : in  std_logic;
    RX        : in  std_logic;
    READ      : in  std_logic;
    DOUT      : out std_logic_vector(7 downto 0);
    RX_EMPTY  : out std_logic;
    RX_COUNT  : out std_logic_vector(31 downto 0)
  );
end RS232RX;


architecture Behavioral of RS232RX is

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

  signal RXcount   : std_logic_vector(3 downto 0);
  signal RXsreg    : std_logic_vector(7 downto 0);

  signal RX_DEL    : std_logic_vector(2 downto 0);
  signal RX_IDLE   : std_logic;

  signal BITcount  : std_logic_vector(3 downto 0);

  signal DATAreg   : std_logic_vector(7 downto 0);

  signal EN        : std_logic;

  signal iUSEDW    : std_logic_vector(UART_FIFO_DEPTH downto 0);
begin

  process(RESET, CLOCK)
  begin
    if RESET='1' then
      RX_DEL <= (others=>'1');
    elsif rising_edge(CLOCK) then
      if BAUD_X_16='1' then
        RX_DEL <= RX_DEL(1 downto 0) & RX;
      end if;
    end if;
  end process;

  process(RESET, CLOCK)
  begin
    if RESET='1' then
      BITcount <= (others=>'0');
      RXcount  <= (others=>'0');
      RX_IDLE  <= '1';
    elsif rising_edge(CLOCK) then
      if BAUD_X_16='1' then
        RXcount <= RXcount + 1;
        if RX_IDLE='1' then
          BITcount <= (others=>'0');
          if RX_DEL(2 downto 1)="00" then
            RXcount  <= (others=>'0');
            RX_IDLE  <='0';
          end if;
        else
          if RXcount="0111" then
            BITcount <= BITcount + 1;
            if BITcount="1001" then
              BITcount <= (others=>'0');
              if RX_DEL(2 downto 1)="11" then
                RX_IDLE <= '1';
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  process(RESET, CLOCK)
  begin
    if RESET='1' then
      EN <= '0';
      RXsreg  <= (others=>'1');
      DATAreg <= (others=>'1');
    elsif rising_edge(CLOCK) then
      EN <= '0';
      if BAUD_X_16='1' and RXcount="0111" then
        RXsreg <= RX_DEL(2) & RXsreg(7 downto 1);
        if BITcount="1001" then
          DATAreg <= RXsreg;
          EN      <= '1';
        end if;
      end if;
    end if;
  end process;

  c_rxfifo : uart_fifo
    port map (
      aclr  => RESET,
      clock => CLOCK,
      data  => DATAreg,
      rdreq => READ,
      sclr  => RESET,
      wrreq => EN,
      empty => RX_EMPTY,
      full  => open,
      q     => DOUT,
      usedw => iUSEDW
    );

  RX_COUNT(UART_FIFO_DEPTH downto 0) <= iUSEDW;
  RX_COUNT(31 downto UART_FIFO_DEPTH+1) <= (others=>'0');

end Behavioral;
