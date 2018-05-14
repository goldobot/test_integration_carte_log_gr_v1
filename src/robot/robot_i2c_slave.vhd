library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

entity robot_i2c_slave is
  port(
    -- reset & clock
    RESET               : in std_logic;
    CLK                 : in std_logic;

    -- generic internal interface
    I2C_MASTER_RD       : out std_logic;
    I2C_MASTER_WR       : out std_logic;
    I2C_MASTER_ADDR     : out std_logic_vector(31 downto 0);
    I2C_MASTER_DATA     : out std_logic_vector(31 downto 0);
    I2C_SLAVE_DATA      : in std_logic_vector(31 downto 0);
    I2C_SLAVE_ACK       : in std_logic;
    I2C_SLAVE_IRQ       : out std_logic;

    -- trace fifo
    TRACE_FIFO          : in std_logic_vector(31 downto 0);
    TRACE_FIFO_DEBUG    : out std_logic_vector(31 downto 0);
    TRACE_FIFO_WR       : in std_logic;
    TRACE_FIFO_FULL     : out std_logic;
    TRACE_FIFO_EMPTY    : out std_logic;

    -- bitstream fifo
    BSTR_FIFO           : out std_logic_vector(31 downto 0);
    BSTR_FIFO_DEBUG     : out std_logic_vector(31 downto 0);
    BSTR_FIFO_RD        : in std_logic;
    BSTR_FIFO_FULL      : out std_logic;
    BSTR_FIFO_EMPTY     : out std_logic;

    -- I2C (external) interface
    SDA_IN              : in     std_logic;
    SDA_OUT             : out    std_logic;
    SDA_EN              : out    std_logic;
    SCL_IN              : in     std_logic;
    SCL_OUT             : out    std_logic;
    SCL_EN              : out    std_logic
    );
end entity;


architecture arch of robot_i2c_slave is

component fifo256x32 is
  port (
    aclr    : in std_logic;
    clock   : in std_logic;
    data    : in std_logic_vector (31 downto 0);
    rdreq   : in std_logic;
    sclr    : in std_logic;
    wrreq   : in std_logic;
    empty   : out std_logic;
    full    : out std_logic;
    q       : out std_logic_vector (31 downto 0)
  );
end component;

signal iI2C_SDA_IN        : std_logic;
signal iI2C_SCL_IN        : std_logic;
signal iI2C_SDA_OUT       : std_logic;
signal iI2C_SCL_OUT       : std_logic;
signal iI2C_SDA_EN        : std_logic;
signal iI2C_SCL_EN        : std_logic;

signal iI2c_waddr         : std_logic;
signal iI2c_write         : std_logic;
signal iI2c_write_old     : std_logic;
signal iI2c_wbusy         : std_logic;
signal iI2c_read          : std_logic;
signal iI2c_read_old      : std_logic;
signal iI2c_rbusy         : std_logic;
signal iI2cRBus           : std_logic_vector( 7 downto 0 );
signal iI2cNoData         : std_logic;
signal iI2cWBus           : std_logic_vector( 7 downto 0 );
signal iI2cDebug          : std_logic_vector( 7 downto 0 );
signal iI2cRegAddr        : std_logic_vector( 7 downto 0 );

signal iI2cRBus_01        : std_logic_vector( 7 downto 0 );
signal iI2cTraceData      : std_logic_vector( 31 downto 0 );
signal iI2cTraceState     : std_logic_vector( 3 downto 0 );
signal iI2cTraceNoData    : std_logic;
signal iI2cNoData_01      : std_logic;
signal iTRACE_FIFO_RD     : std_logic;
signal iTRACE_FIFO_RD2    : std_logic;
signal iTRACE_FIFO_EMPTY  : std_logic;
signal iTRACE_FIFO_FULL   : std_logic;
signal iTRACE_FIFO_RDATA  : std_logic_vector( 31 downto 0 );

signal iI2cBstrData       : std_logic_vector( 31 downto 0 );
signal iI2cBstrState      : std_logic_vector( 3 downto 0 );
signal iI2cBstrNoData     : std_logic;
signal iBSTR_FIFO_RD_OLD  : std_logic;

signal iI2cRBus_05        : std_logic_vector( 7 downto 0 );
signal iI2cNoData_05      : std_logic;
signal iI2C_MASTER_RD     : std_logic;
signal iI2C_MASTER_WR     : std_logic;
signal iI2C_MASTER_ADDR   : std_logic_vector(31 downto 0);
signal iI2C_MASTER_DATA   : std_logic_vector(31 downto 0);
signal iI2C_SLAVE_DATA    : std_logic_vector(31 downto 0);

signal iMstAddrState      : std_logic_vector( 3 downto 0 );
signal iMstDataState      : std_logic_vector( 3 downto 0 );
signal iSlvDataState      : std_logic_vector( 3 downto 0 );


begin

iI2C_SDA_IN <= SDA_IN;
SDA_OUT <= iI2C_SDA_OUT;
SDA_EN <= iI2C_SDA_EN;

iI2C_SCL_IN <= SCL_IN;
SCL_OUT <= iI2C_SCL_OUT;
SCL_EN <= iI2C_SCL_EN;

c_i2c_core : entity work.I2C_SLAVE_CORE
  generic map (
    CLK_FREQ => 25000000,
    BAUD     => 400000
    )
  port map (
    SYS_CLK     => CLK,
    SYS_RST     => RESET,
    SLV_DIN     => iI2cRBus,
    SLV_NODATA  => iI2cNoData,
    SLV_ADDR    => X"42",
    SLV_READ    => iI2c_read,
    SLV_RBUSY   => iI2c_rbusy,
    SLV_WRITE   => iI2c_write,
    SLV_WBUSY   => iI2c_wbusy,
    SLV_WADDR   => iI2c_waddr,
    SLV_BUSY    => open,
    SLV_DOUT    => iI2cWBus,
    I2C_DEBUG   => iI2cDebug,
    SDA_IN      => iI2C_SDA_IN,
    SDA_OUT     => iI2C_SDA_OUT,
    SDA_EN      => iI2C_SDA_EN,
    SCL_IN      => iI2C_SCL_IN,
    SCL_OUT     => iI2C_SCL_OUT,
    SCL_EN      => iI2C_SCL_EN
    );


p_i2c_ctrl: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2c_read_old <= '0';
    iI2c_write_old <= '0';
    iI2cRegAddr <= (others => '1');
  elsif CLK'event and CLK = '1' then  
    iI2c_read_old <= iI2c_read;
    iI2c_write_old <= iI2c_write;
    if (iI2c_waddr = '1') then
      iI2cRegAddr <= iI2cWBus;
    end if;
  end if;
end process p_i2c_ctrl;


-- trace (fifo) interface
c_trace_fifo256x32 : fifo256x32 port map (
    aclr   => RESET,
    clock  => CLK,
    data   => TRACE_FIFO,
    rdreq  => iTRACE_FIFO_RD,
    sclr   => '0',
    wrreq  => TRACE_FIFO_WR,
    empty  => iTRACE_FIFO_EMPTY,
    full   => iTRACE_FIFO_FULL,
    q      => iTRACE_FIFO_RDATA
  );

p_i2c_trace: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2cTraceData <= X"00000000";
    iI2cTraceState <= X"0";
    iI2cTraceNoData <= '1';
    iI2cNoData_01 <= '1';
    iI2cRBus_01 <= X"42";
    iTRACE_FIFO_RD <= '0';
    iTRACE_FIFO_RD2 <= '0';
  elsif CLK'event and CLK = '1' then  
    if (iI2cRegAddr = X"01") then
      if (iI2c_read = '1') and (iI2c_read_old = '0') then
        case iI2cTraceState is
          when X"0" =>
            iI2cRBus_01 <= iI2cTraceData(31 downto 24);
            iI2cTraceState <= X"1";
          when X"1" =>
            iI2cRBus_01 <= iI2cTraceData(23 downto 16);
            iI2cTraceState <= X"2";
          when X"2" =>
            iI2cRBus_01 <= iI2cTraceData(15 downto 8);
            iI2cTraceState <= X"3";
          when X"3" =>
            iI2cRBus_01 <= iI2cTraceData(7 downto 0);
            iI2cTraceState <= X"0";
            iI2cTraceNoData <= '1';
            iI2cNoData_01 <= '1';
          when others =>
            iI2cRBus_01 <= X"42";
        end case;
      end if;
    end if;

    if (iTRACE_FIFO_EMPTY='0') and (iI2c_rbusy='0') and
      (iI2cTraceNoData='1') and (iTRACE_FIFO_RD = '0') then
      iTRACE_FIFO_RD <= '1';
      iI2cTraceNoData <= '0';
    end if;

    if (iTRACE_FIFO_RD = '1') then
      iTRACE_FIFO_RD <= '0';
      iTRACE_FIFO_RD2 <= '1';
    end if;

    if (iTRACE_FIFO_RD2 = '1') then
      iI2cTraceData <= iTRACE_FIFO_RDATA;
      iI2cTraceState <= X"0";
      iI2cNoData_01 <= '0';
      iTRACE_FIFO_RD2 <= '0';
    end if;
  end if;
end process p_i2c_trace;
TRACE_FIFO_FULL <= iTRACE_FIFO_FULL;
TRACE_FIFO_EMPTY <= iTRACE_FIFO_EMPTY;
TRACE_FIFO_DEBUG <= iTRACE_FIFO_RDATA;


-- firmware (or command) interface
p_i2c_bstr: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2cBstrData <= X"DEADBEEF";
    BSTR_FIFO <= X"DEADBEEF";
    BSTR_FIFO_FULL <= '0';
    iI2cBstrState <= X"0";
    iI2cBstrNoData <= '1';
    iBSTR_FIFO_RD_OLD <= '0';
  elsif CLK'event and CLK = '1' then  
    if (iI2cRegAddr = X"02") then
      if (iI2c_write = '1') and (iI2c_write_old = '0') then
        case iI2cBstrState is
          when X"0" =>
            iI2cBstrData(31 downto 24) <= iI2cWBus;
            iI2cBstrState <= X"1";
          when X"1" =>
            iI2cBstrData(23 downto 16) <= iI2cWBus;
            iI2cBstrState <= X"2";
          when X"2" =>
            iI2cBstrData(15 downto 8) <= iI2cWBus;
            iI2cBstrState <= X"3";
          when X"3" =>
            iI2cBstrData(7 downto 0) <= iI2cWBus;
            iI2cBstrState <= X"0";
            iI2cBstrNoData <= '0';
            BSTR_FIFO <= iI2cBstrData(31 downto 8) & iI2cWBus;
            BSTR_FIFO_FULL <= '1';
          when others =>
            null;
        end case;
      end if;
    end if;

    if (BSTR_FIFO_RD = '1') and (iBSTR_FIFO_RD_OLD = '0') then
      if (iI2cBstrNoData = '0') then
        iI2cBstrState <= X"0";
        iI2cBstrNoData <= '1';
        BSTR_FIFO <= X"ABADCAFE";
        BSTR_FIFO_FULL <= '0';
      end if;
    end if;
    iBSTR_FIFO_RD_OLD <= BSTR_FIFO_RD;
  end if;
end process p_i2c_bstr;
BSTR_FIFO_EMPTY <= iI2cBstrNoData;
BSTR_FIFO_DEBUG <= iI2cBstrData;


-- robot master interface
-- FIXME : TODO ++
I2C_SLAVE_IRQ <= '0';
-- FIXME : TODO --

-- robot master addr
p_mst_addr: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2C_MASTER_ADDR <= (others => '0');
    iMstAddrState <= X"0";
  elsif CLK'event and CLK = '1' then  
    if (iI2cRegAddr = X"03") then
      if (iI2c_write = '1') and (iI2c_write_old = '0') then
        case iMstAddrState is
          when X"0" =>
            iI2C_MASTER_ADDR(31 downto 24) <= iI2cWBus;
            iMstAddrState <= X"1";
          when X"1" =>
            iI2C_MASTER_ADDR(23 downto 16) <= iI2cWBus;
            iMstAddrState <= X"2";
          when X"2" =>
            iI2C_MASTER_ADDR(15 downto 8) <= iI2cWBus;
            iMstAddrState <= X"3";
          when X"3" =>
            iI2C_MASTER_ADDR(7 downto 0) <= iI2cWBus;
            iMstAddrState <= X"0";
          when others =>
            null;
        end case;
      end if;
    end if;
  end if;
end process p_mst_addr;
I2C_MASTER_ADDR <= iI2C_MASTER_ADDR;

-- robot master data write
p_mst_data_wr: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2C_MASTER_WR <= '0';
    iI2C_MASTER_DATA <= (others => '0');
    iMstDataState <= X"0";
  elsif CLK'event and CLK = '1' then  
    if (iI2cRegAddr = X"04") then
      case iMstDataState is
        when X"0" =>
          iI2C_MASTER_WR <= '0';
          if (iI2c_write = '1') and (iI2c_write_old = '0') then
            iI2C_MASTER_DATA(31 downto 24) <= iI2cWBus;
            iMstDataState <= X"1";
          end if;
        when X"1" =>
          if (iI2c_write = '1') and (iI2c_write_old = '0') then
            iI2C_MASTER_DATA(23 downto 16) <= iI2cWBus;
            iMstDataState <= X"2";
          end if;
        when X"2" =>
          if (iI2c_write = '1') and (iI2c_write_old = '0') then
            iI2C_MASTER_DATA(15 downto 8) <= iI2cWBus;
            iMstDataState <= X"3";
          end if;
        when X"3" =>
          if (iI2c_write = '1') and (iI2c_write_old = '0') then
            iI2C_MASTER_DATA(7 downto 0) <= iI2cWBus;
            iMstDataState <= X"4";
          end if;
        when X"4" =>
          iI2C_MASTER_WR <= '1';
          iMstDataState <= X"5";
        when X"5" =>
          iI2C_MASTER_WR <= '0';
          iMstDataState <= X"0";
        when others =>
          null;
      end case;
    end if;
  end if;
end process p_mst_data_wr;
I2C_MASTER_WR <= iI2C_MASTER_WR;
I2C_MASTER_DATA <= iI2C_MASTER_DATA;

-- robot master data read
p_mst_data_rd: process (CLK, RESET)
begin
  if RESET = '1' then
    iI2C_MASTER_RD <= '0';
    iI2C_SLAVE_DATA <= (others => '0');
    iSlvDataState <= X"0";
    iI2cRBus_05 <= X"73";
    iI2cNoData_05 <= '1';
  elsif CLK'event and CLK = '1' then  
-- FIXME : TODO : improve management of data source(s)
    if (iI2c_waddr = '1') and (iI2cWBus = X"05") then
      iI2C_MASTER_RD <= '1';
    else
      iI2C_MASTER_RD <= '0';
    end if;

    if (iI2C_MASTER_RD = '1') then
      iI2cNoData_05 <= '0';
      iI2C_SLAVE_DATA <= I2C_SLAVE_DATA;
    end if;

    if (iI2cRegAddr = X"05") then
      if (iI2c_read = '1') and (iI2c_read_old = '0') then
        case iSlvDataState is
          when X"0" =>
            iI2cRBus_05 <= iI2C_SLAVE_DATA(31 downto 24);
            iSlvDataState <= X"1";
          when X"1" =>
            iI2cRBus_05 <= iI2C_SLAVE_DATA(23 downto 16);
            iSlvDataState <= X"2";
          when X"2" =>
            iI2cRBus_05 <= iI2C_SLAVE_DATA(15 downto 8);
            iSlvDataState <= X"3";
          when X"3" =>
            iI2cRBus_05 <= iI2C_SLAVE_DATA(7 downto 0);
            iI2cNoData_05 <= '1';
            iSlvDataState <= X"0";
          when others =>
            iI2cRBus_05 <= X"73";
            iI2cNoData_05 <= '1';
        end case;
      end if;
    end if;
  end if;
end process p_mst_data_rd;
I2C_MASTER_RD <= iI2C_MASTER_RD;

iI2cRBus   <= iI2cRBus_01   when (iI2cRegAddr = X"01") else
              iI2cRBus_05   when (iI2cRegAddr = X"05") else X"33";
iI2cNoData <= iI2cNoData_01 when (iI2cRegAddr = X"01") else
              iI2cNoData_05 when (iI2cRegAddr = X"05") else '1';

end arch;

