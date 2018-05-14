---------------------------------------------------------------------
--
-- i2c_slave core
-- derived from i2c.i2c_core_v02.vhd (see old file)
--
-- Author : Florentin "Goldorak" Demetrescu (echelon@free.fr)
--
---------------------------------------------------------------------
-- Copyright (C) 2011 Florentin Demetrescu
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation; either version 2 of
-- the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston,
-- MA 02111-1307 USA
--
---------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity I2C_SLAVE_CORE is
  generic
    (
      CLK_FREQ   : natural := 25000000;
      BAUD       : natural := 400000
    );
  port
    ( 
      --INPUTS
      SYS_CLK    : in     std_logic;
      SYS_RST    : in     std_logic;
      SLV_DIN    : in     std_logic_vector ( 7 downto 0 );
      SLV_NODATA : in     std_logic;
-- /!\ BEWARE : only the bits (6 downto 0) of SLV_ADDR are meaningfull /!\
      SLV_ADDR   : in     std_logic_vector ( 7 downto 0 );
      --OUTPUTS
      SLV_READ   : out    std_logic;
      SLV_RBUSY  : out    std_logic;
      SLV_WRITE  : out    std_logic;     
      SLV_WBUSY  : out    std_logic;
      SLV_WADDR  : out    std_logic;
      SLV_BUSY   : out    std_logic;
      SLV_DOUT   : out    std_logic_vector( 7 downto 0 );
      --FIXME : DEBUG
      I2C_DEBUG  : out    std_logic_vector( 7 downto 0 );
      --I2C bus signals
      SDA_IN     : in     std_logic;
      SDA_OUT    : out    std_logic;
      SDA_EN     : out    std_logic;
      SCL_IN     : in     std_logic;
      SCL_OUT    : out    std_logic;
      SCL_EN     : out    std_logic
    );
end entity I2C_SLAVE_CORE;


architecture RTL of I2C_SLAVE_CORE is

-- constants
  
constant FULL_BIT  : natural := CLK_FREQ / BAUD;
constant HALF_BIT  : natural := FULL_BIT / 2;  -- FIXME : TODO : use this!
constant GAP_WIDTH : natural := FULL_BIT * 2;  -- FIXME : TODO : use this!


-- signals related to the external interface (i2c slave interface)
  
signal i_slv_sda_fall : std_logic;
signal i_slv_sda_rise : std_logic;
signal i_slv_scl_fall : std_logic;
signal i_slv_scl_rise : std_logic;

signal i_sda_sam      : std_logic_vector( 1 downto 0 );
signal i_scl_sam      : std_logic_vector( 1 downto 0 );

signal i_sda_slv_en   : std_logic;


-- signals related to the internal interface
-- (to other modules of the FPGA design)

signal i_slv_addr     : std_logic_vector( 7 downto 0 );
signal i_slv_d_send   : std_logic_vector( 7 downto 0 );
signal i_slv_d_recv   : std_logic_vector( 7 downto 0 );

signal i_reg_addr_flag    : std_logic;


-- other signals

signal i_slv_bit_cnt  : natural range 0 to 10;
signal i_slv_stop_bit : std_logic;
signal i_slv_strt_bit : std_logic;


type i2c_slave_state is (
  slv_idle ,
  slv_recv_addr ,
  slv_recv_addr_ack ,
  slv_recv_addr_ack_hold ,
  slv_recv_data ,
  slv_recv_data_send_ack ,
  slv_recv_data_send_ack_hold ,
  slv_send_data ,
  slv_send_data_wait_ack ,
  slv_send_data_wait_ack_hold
);

signal stm_slv : i2c_slave_state;


begin

SDA_OUT  <= '0';
SDA_EN   <= i_sda_slv_en;
SCL_OUT  <= '1';
SCL_EN   <= '0';

SLV_WBUSY <= '1' when ((stm_slv = slv_recv_data_send_ack_hold))
             else '0';
SLV_RBUSY <= '1' when ((stm_slv = slv_recv_addr_ack_hold) or
                       (stm_slv = slv_send_data) or
                       (stm_slv = slv_send_data_wait_ack_hold))
             else '0';

p_synchronisation : process( SYS_CLK , SYS_RST )
begin
  if ( SYS_RST = '1' ) then
    i_scl_sam( 0 ) <= '0';
    i_scl_sam( 1 ) <= '0';
    i_sda_sam( 0 ) <= '0';
    i_sda_sam( 1 ) <= '0';
  elsif rising_edge( SYS_CLK ) then
    i_scl_sam( 0 ) <= SCL_IN;
    i_scl_sam( 1 ) <= i_scl_sam( 0 );
    i_sda_sam( 0 ) <= SDA_IN;
    i_sda_sam( 1 ) <= i_sda_sam( 0 );
  end if;
end process p_synchronisation;


i_slv_sda_fall <= not i_sda_sam( 0 ) and i_sda_sam( 1 );
i_slv_sda_rise <= i_sda_sam( 0 ) and not i_sda_sam( 1 );    
  
i_slv_scl_fall <= not i_scl_sam( 0 ) and i_scl_sam( 1 );
i_slv_scl_rise <= i_scl_sam( 0 ) and not i_scl_sam( 1 );

i_slv_stop_bit <= '1' when (i_slv_sda_rise='1') and (to_X01(i_scl_sam(0))='1')
                  else '0'; 
i_slv_strt_bit <= '1' when (i_slv_sda_fall='1') and (to_X01(i_scl_sam(0))='1')
                  else '0';


p_i2c_slave : process( SYS_CLK , SYS_RST )
begin
  if ( SYS_RST = '1' ) then
    stm_slv <= slv_idle;
    SLV_BUSY <= '0';
    i_slv_bit_cnt <= 0;
    i_slv_addr <= ( others => '0' );
    i_sda_slv_en <= '0';
    i_slv_d_recv <= ( others => '0' );
    i_slv_d_send <= ( others => '0' );
    SLV_READ <= '0';
    SLV_WRITE <= '0';
    SLV_WADDR <= '0';
    SLV_DOUT <= ( others => '0' );
    i_reg_addr_flag <= '0';
  elsif rising_edge( SYS_CLK ) then
    case stm_slv is
      ----------------------
      when slv_idle =>
        SLV_BUSY <= '0';
        i_reg_addr_flag <= '0';
        i_sda_slv_en <= '0';
        i_slv_bit_cnt <= 0;
        if ( i_slv_strt_bit = '1' ) then
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
        end if;
      ----------------------
      when slv_recv_addr =>
        i_sda_slv_en <= '0';
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        else
          if ( i_slv_scl_rise = '1' ) then
            if ( i_slv_bit_cnt < 7 ) then               
              i_slv_addr <= i_slv_addr( 6 downto 0 ) & i_sda_sam(0);
              i_slv_bit_cnt <= i_slv_bit_cnt + 1;  
            elsif( i_slv_bit_cnt = 7 ) then
              i_slv_addr <= i_slv_addr( 6 downto 0 ) & i_sda_sam(0);
              i_slv_bit_cnt <= 0; 
              stm_slv <= slv_recv_addr_ack;                 
            end if;
          end if;
        end if;
      ----------------------
      when slv_recv_addr_ack =>
        I2C_DEBUG <= i_slv_addr;
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        elsif ( i_slv_strt_bit = '1' ) then  
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
          i_reg_addr_flag <= '0';
          i_sda_slv_en <= '0';
          i_slv_bit_cnt <= 0;
        elsif ( i_slv_addr( 7 downto 1 ) = SLV_ADDR( 6 downto 0 ) ) then  
          if ( i_slv_addr( 0 ) = '1' ) then -- master read
            if ( SLV_NODATA = '0' ) then -- has something to send
              if ( i_slv_scl_fall = '1' ) then
                i_sda_slv_en <= '1';
                stm_slv <= slv_recv_addr_ack_hold;
              end if;
            else -- nothing to send!..
              stm_slv <= slv_idle;
            end if;
          else -- master write (always accept..)
            if ( i_slv_scl_fall = '1' ) then
              i_sda_slv_en <= '1';
              stm_slv <= slv_recv_addr_ack_hold;
            end if;
          end if;
        else
          stm_slv <= slv_idle;
        end if;
      ----------------------
      when slv_recv_addr_ack_hold =>
        if ( i_slv_scl_fall = '1' ) then
          i_sda_slv_en <= '0';
          if ( i_slv_addr( 0 ) = '0' ) then -- master write
            i_reg_addr_flag <= '1';
            stm_slv <= slv_recv_data;
          else -- ( i_slv_addr( 0 ) = '1' ) -- master read
            SLV_READ <= '1';
            stm_slv <= slv_send_data;
          end if;
        end if;
      ----------------------
      when slv_recv_data =>
        SLV_WRITE <= '0';
        SLV_WADDR <= '0';
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        elsif ( i_slv_strt_bit = '1' ) then  
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
          i_reg_addr_flag <= '0';
          i_sda_slv_en <= '0';
          i_slv_bit_cnt <= 0;
        else
          if ( i_slv_scl_rise = '1' ) then
            if ( i_slv_bit_cnt < 7 ) then               
              i_slv_d_recv <= i_slv_d_recv( 6 downto 0 )& i_sda_sam(0);
              i_slv_bit_cnt <= i_slv_bit_cnt + 1; 
            elsif ( i_slv_bit_cnt = 7 ) then
              i_slv_d_recv <= i_slv_d_recv( 6 downto 0 )& i_sda_sam(0);
              i_slv_bit_cnt <= 0;
              stm_slv <= slv_recv_data_send_ack;
            end if;       
          end if;             
        end if;
      ----------------------
      when slv_recv_data_send_ack =>  
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        elsif ( i_slv_strt_bit = '1' ) then  
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
          i_reg_addr_flag <= '0';
          i_sda_slv_en <= '0';
          i_slv_bit_cnt <= 0;
        elsif ( i_slv_scl_fall = '1' ) then
          i_sda_slv_en <= '1';
          stm_slv <= slv_recv_data_send_ack_hold;
        end if;                  
      ----------------------
      when slv_recv_data_send_ack_hold =>
        if ( i_slv_scl_fall = '1' ) then
          i_sda_slv_en <= '0';
          SLV_DOUT <= i_slv_d_recv;
          if ( i_reg_addr_flag = '1' ) then
            i_reg_addr_flag <= '0';
            SLV_WADDR <= '1';
          else
            SLV_WRITE <= '1';
          end if;             
          stm_slv <= slv_recv_data;
        end if;  
      ----------------------
      when slv_send_data =>
        SLV_READ <= '0';
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        elsif ( i_slv_strt_bit = '1' ) then  
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
          i_reg_addr_flag <= '0';
          i_sda_slv_en <= '0';
          i_slv_bit_cnt <= 0;
        else
          if ( i_slv_scl_fall = '1' ) then
            if ( i_slv_bit_cnt < 7 ) then
              i_slv_d_send <= i_slv_d_send( 6 downto 0 ) & '0';
              i_slv_bit_cnt <= i_slv_bit_cnt + 1;
              stm_slv <= slv_send_data;
            elsif ( i_slv_bit_cnt = 7 ) then
              i_slv_bit_cnt <= 0;
              stm_slv <= slv_send_data_wait_ack;
            end if;
          elsif ( i_slv_bit_cnt = 0 ) then
            i_slv_d_send <= SLV_DIN; 
          end if;
          if ( i_slv_d_send( 7 ) = '0' ) then
            i_sda_slv_en <= '1';
          else
            i_sda_slv_en <= '0';
          end if;
        end if;
      ----------------------
      when slv_send_data_wait_ack =>
        i_sda_slv_en <= '0';
        if ( i_slv_stop_bit = '1' ) then
          stm_slv <= slv_idle;
        elsif ( i_slv_strt_bit = '1' ) then  
          stm_slv <= slv_recv_addr;
          SLV_BUSY <= '1';
          i_reg_addr_flag <= '0';
          i_sda_slv_en <= '0';
          i_slv_bit_cnt <= 0;
        elsif ( i_slv_scl_rise = '1' ) then
          if ( i_sda_sam(0) = '0' ) and ( i_slv_sda_fall = '0' ) then
            stm_slv <= slv_send_data_wait_ack_hold;
          else
            stm_slv <= slv_idle;
          end if;
        end if;
      ----------------------
      when slv_send_data_wait_ack_hold =>
        i_sda_slv_en <= '0';
        if ( i_slv_scl_fall = '1' ) then
          if ( i_sda_sam(0) = '0' ) and ( i_slv_sda_fall = '0' ) then
            i_sda_slv_en <= '0';
            stm_slv <= slv_send_data;                              
            SLV_READ <= '1';
          else
            stm_slv <= slv_idle;
          end if;
        end if;
      ----------------------
      when others => stm_slv <= slv_idle;
    end case;  
  end if;
end process p_i2c_slave;


end RTL;
