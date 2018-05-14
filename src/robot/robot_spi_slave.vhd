----------------------------------------------------------------------------
---- robot_spi_slave : esclave SPI                                      ----
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

entity robot_spi_slave is
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
end robot_spi_slave;

architecture robot_spi_slave_arch of robot_spi_slave is

  constant zero48 : std_logic_vector(47 downto 0) := (others => '0');
  constant zero32 : std_logic_vector(31 downto 0) := (others => '0');
  constant zero16 : std_logic_vector(15 downto 0) := (others => '0');
  constant zero8  : std_logic_vector(7 downto 0)  := (others => '0');

  signal iSPI_MASTER_ADDR  : std_logic_vector(31 downto 0);
  signal iSPI_MASTER_DATA  : std_logic_vector(31 downto 0);
  signal iSPI_SLAVE_DATA   : std_logic_vector(31 downto 0);

  signal iSPI_MOSI         : std_logic;
  signal iSPI_MOSI_OLD     : std_logic;
  signal iSPI_MOSI_OLD2    : std_logic;
  signal iSPI_CLK          : std_logic;
  signal iSPI_CLK_OLD      : std_logic;

  signal iPERIOD_DETECT    : std_logic_vector(31 downto 0);
  signal iBITCNT           : std_logic_vector(7 downto 0);

  signal iRECV_SR          : std_logic_vector(47 downto 0);
  signal iSEND_SR          : std_logic_vector(47 downto 0);

  signal iRECV_DATA        : std_logic_vector(47 downto 0);

  signal iREG_SELECT       : std_logic_vector(3 downto 0);

  signal iSPI_MASTER_RD    : std_logic;
  signal iSPI_MASTER_WR    : std_logic;

begin

  latch_proc : process (CLK, RESET)
  begin
    if RESET = '1' then
      iSPI_MOSI <= '0';
      iSPI_MOSI_OLD <= '0';
      iSPI_MOSI_OLD2 <= '0';
      iSPI_CLK <= '0';
      iSPI_CLK_OLD <= '0';
    elsif rising_edge(CLK) then
      iSPI_MOSI <= SPI_MOSI;
      iSPI_MOSI_OLD <= iSPI_MOSI;
      iSPI_MOSI_OLD2 <= iSPI_MOSI_OLD;
      iSPI_CLK <= SPI_CLK;
      iSPI_CLK_OLD <= iSPI_CLK;
    end if;
  end process;

  slave_spi_proc : process (CLK, RESET)
    variable iRECV_SR_NEXT : std_logic_vector(47 downto 0) := zero48;
    variable iSLV_DATA_NEXT : std_logic_vector(31 downto 0) := zero32;
  begin
    if RESET = '1' then
      iRECV_SR         <= zero48;
      iSEND_SR         <= (others => '1');
      iPERIOD_DETECT   <= zero32;
      iBITCNT          <= zero8;
      iREG_SELECT      <= "0000";
      iSPI_MASTER_RD    <= '0';
      iSPI_MASTER_WR    <= '0';
      iSPI_MASTER_ADDR <= zero32;
      iSPI_MASTER_DATA <= zero32;
      iSPI_SLAVE_DATA  <= zero32;
    elsif rising_edge(CLK) then
      if (iSPI_CLK_OLD = '0') and (iSPI_CLK = '1') then
        iPERIOD_DETECT <= zero32;
      else
        if (iPERIOD_DETECT/=X"FFFFFFF0") then
          iPERIOD_DETECT <= iPERIOD_DETECT + 1;
        end if;
      end if;
      if (iPERIOD_DETECT=X"00000080") then
        iRECV_SR    <= zero48;
        iBITCNT     <= zero8;
        iREG_SELECT <= "0000";
      else
        if (iSPI_CLK_OLD = '0') and (iSPI_CLK = '1') then
          if (iBITCNT = X"00") then
            iSEND_SR         <= (others => '1');
          elsif (iBITCNT = X"07") then
            case iREG_SELECT is
              when X"0" =>
                iSLV_DATA_NEXT := DBG_SLV_DATA;
              when X"1" =>
                iSLV_DATA_NEXT := X"55AA55AA"; -- FIXME : TODO : trace
              when X"2" =>
                iSLV_DATA_NEXT := X"55AA55AA"; -- FIXME : TODO : leon bstream
              when X"3" =>
                iSLV_DATA_NEXT := iSPI_MASTER_ADDR;
              when X"4" =>
                iSLV_DATA_NEXT := iSPI_MASTER_DATA;
              when X"5" =>
                iSLV_DATA_NEXT := iSPI_SLAVE_DATA;
              when others =>
                iSLV_DATA_NEXT := X"55AA55AA";
            end case;
            iSEND_SR <= iSLV_DATA_NEXT &
                        (iSLV_DATA_NEXT(31 downto 24) xor
                         iSLV_DATA_NEXT(23 downto 16) xor
                         iSLV_DATA_NEXT(15 downto 8)  xor
                         iSLV_DATA_NEXT(7 downto 0)) &
                        "11111111";
          else
            iSEND_SR <= iSEND_SR(46 downto 0) & '1';
          end if;
        end if;
-- FIXME : TODO : implementer un registre de mode avec flags CPOL et CPHA
--        if (iSPI_CLK_OLD = '1') and (iSPI_CLK = '0') then
        if (iSPI_CLK_OLD = '0') and (iSPI_CLK = '1') then
          iRECV_SR_NEXT := iRECV_SR(46 downto 0) & iSPI_MOSI_OLD2;
          iRECV_SR <= iRECV_SR_NEXT;
          iBITCNT <= iBITCNT + 1;
          if (iBITCNT = X"03") then
            iREG_SELECT <= iRECV_SR_NEXT(3 downto 0);
          end if;
          if (iBITCNT = X"04") then
            if (iREG_SELECT = X"5") then
              iSPI_MASTER_RD <= '1';
            end if;
          end if;
          if (iBITCNT = X"2F") then
            case iREG_SELECT is
              when X"0" =>
                DBG_MST_DATA <= iRECV_SR_NEXT(39 downto 8);
              when X"1" =>
                null; -- FIXME : TODO : trace
              when X"2" =>
                null; -- FIXME : TODO : leon bstream
              when X"3" =>
                iSPI_MASTER_ADDR <= iRECV_SR_NEXT(39 downto 8);
              when X"4" =>
                iSPI_MASTER_DATA <= iRECV_SR_NEXT(39 downto 8);
                iSPI_MASTER_WR <= '1';
              when X"5" =>
                null; -- SPI_SLAVE_DATA
              when others =>
                null;
            end case;
            iBITCNT <= zero8;
          end if;
        end if;
      end if;
      if (iSPI_MASTER_WR = '1') then
        iSPI_MASTER_WR <= '0';
      end if;
      if (iSPI_MASTER_RD = '1') then
        iSPI_SLAVE_DATA <= SPI_SLAVE_DATA;
        iSPI_MASTER_RD <= '0';
      end if;
    end if;
  end process;

  SPI_MASTER_ADDR  <= iSPI_MASTER_ADDR;

  SPI_MASTER_DATA  <= iSPI_MASTER_DATA;

  SPI_MASTER_WR    <= iSPI_MASTER_WR;
--  SPI_MASTER_WR    <= '0';

  SPI_MASTER_RD    <= iSPI_MASTER_RD;

  SPI_MISO <= iSEND_SR(47);
--  SPI_MISO <= '1';

  SPI_SLAVE_IRQ <= '0';

end robot_spi_slave_arch;
