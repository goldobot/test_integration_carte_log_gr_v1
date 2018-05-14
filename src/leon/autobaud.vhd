--//////////////////////////////////////////////////////////////////////
--
--  Abstract: Uart has an auto-tuning baud rate generator
--            This is an auto-tuning baud rate generator.
--  Module  : BAUD_GEN.v
--
--  Version : ver 01.00
--
--  Modification History:
--  Date By         Change Description
--  -----------------------------------------------------------------
--  2008/06/24  jackie
--  YYYY/MM/DD  author     Revision content
--
--//////////////////////////////////////////////////////////////////////
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity autobaud is
  generic (
    BAUD19200	: std_logic_vector(14 downto 0) := "000000001100111";
    SYN_NUM		: std_logic_vector(7 downto 0) := "00000100"
    );
  port (
    rst		: in	std_logic;
    clk		: in	std_logic;
    baud_rst	: in	std_logic;
    rxd		: in	std_logic;
    baud_out	: out	std_logic;
    lock	: out	std_logic;
    scale	: out	std_logic_vector(14 downto 0)
    );
end entity;

architecture rtl of autobaud is

  signal posedge_cnt	: unsigned(14 downto 0);
  signal negedge_cnt	: unsigned(14 downto 0);
  signal baud_value	: unsigned(14 downto 0);
  signal baud_value1	: unsigned(14 downto 0);
  signal baud_cnt		: unsigned(14 downto 0);
  signal syn_cnt		: unsigned(7 downto 0);
  signal rxd_q		: std_logic;
  signal syn_ok		: std_logic;
  signal syn_ok_q		: std_logic;
  signal go_pos_cnt	: std_logic;
  signal go_neg_cnt	: std_logic;
  signal rx_baudrate	: std_logic;
  signal baud_value_tmp 	: unsigned(14 downto 0);
  signal delay_lock_signal 	: integer range 0 to 100;
  signal start_cnt	: std_logic;
  signal scale_compute0 	: integer range 0 to 4095;
  signal compute0	: std_logic;
  signal scale_compute1 	: integer range 0 to 4095;
  signal compute1	: std_logic;
  signal scale_std	: std_logic_vector(14 downto 0);
  signal scale_15	: std_logic_vector(14 downto 0);

  signal scale1	: std_logic_vector(11 downto 0);
begin

  baud_value_tmp <= baud_value1 when syn_ok = '1' else unsigned(BAUD19200);
  baud_out <= rx_baudrate;
  rx_baudrate <= '1' when ((baud_cnt<=(baud_value_tmp))and (baud_cnt>=(baud_value_tmp(14 downto 1)))) else '0';
  lock <= syn_ok;
  
  -- process(clk,rst)
  -- variable scale_temp	: std_logic_vector(12 downto 0);
  -- begin
  -- if rst = '0' then
  -- scale <= (others => '0');
  -- scale_compute <= 0;
  -- compute <= '1';
  -- elsif rising_edge(clk) then
  -- if compute = '1' then
  -- if (rxd ='0') then
    -- scale_compute <= scale_compute+1;
  -- else
    -- if (scale_compute) > 0 then
      -- compute <= '0';
        -- scale_temp := std_logic_vector( to_unsigned( scale_compute+8, 13 ) );
          -- scale <= "00" & scale_temp(12 downto 3);
            -- end if;
  -- end if;
  -- end if;		
  -- end if;
  -- end process;
  
  process(clk,rst)
    variable scale_temp	: std_logic_vector(13 downto 0);
  begin
    if rst = '0' then
      scale1 <= (others => '0');
      scale_compute0 <= 0;
      compute0 <= '1';
      scale_compute1 <= 1;
      compute1 <= '1';
    elsif rising_edge(clk) then
      if compute0 = '1' then
        if (rxd ='0') then
          if (scale_compute0 < 4095) then
            scale_compute0 <= scale_compute0+1;
          end if;
          scale_compute1 <= 1;
          compute1 <= '1';
          
        else
          if (scale_compute0) > 0 then
            compute0 <= '0';
          end if;
        end if;
      elsif compute1 = '1' then
        if (rxd ='1') then
          if (scale_compute1 < 4095) then
            scale_compute1 <= scale_compute1+1;
          end if;
        else
          if (scale_compute1) > 1 then
            compute1 <= '0';
            scale_temp := std_logic_vector( to_unsigned( scale_compute0+scale_compute1+16, 14 ) );
                                        ----scale_temp := std_logic_vector( to_unsigned( scale_compute0+scale_compute1, 14 ) );
            scale1 <= "00" & scale_temp(13 downto 4);
            
            scale_compute0 <= 1;
            compute0 <= '1';
          end if;
        end if;
      end if;		
    end if;
  end process;
  

--	scale <= "000" & scale1;
  scale <= std_logic_vector(baud_value1);

  --process(clk,rst)
  process(clk,rst,baud_rst)
    variable posedge_lower	: unsigned(14 downto 0);
    variable posedge_upper	: unsigned(14 downto 0);
  begin
    --if rst = '0' then
    if (rst = '0' or baud_rst = '1') then
      baud_cnt <= (others => '0');
      syn_ok_q <= '0';
      rxd_q <= '1';
      go_pos_cnt <= '0';
      go_neg_cnt <= '0';
      posedge_cnt <= (others => '1');
      negedge_cnt <= (others => '1');
      syn_cnt <= (others => '0');
      syn_ok <= '0';
      baud_value <= (others => '1');
      baud_value1 <= unsigned(BAUD19200);
      posedge_lower := (others => '0');
      posedge_upper := (others => '0');
    elsif rising_edge(clk) then
      -- if baud_rst = '1' then
      -- baud_cnt <= (others => '0');
      -- syn_ok_q <= '0';
      -- rxd_q <= '1';
      -- go_pos_cnt <= '0';
      -- go_neg_cnt <= '0';
      -- posedge_cnt <= (others => '1');
      -- negedge_cnt <= (others => '1');
      -- syn_cnt <= (others => '0');
      -- syn_ok <= '0';
      -- baud_value <= (others => '1');
      -- baud_value1 <= unsigned(BAUD19200);
      -- posedge_lower := (others => '0');
      -- posedge_upper := (others => '0');
      -- end if;
      -- capture a edge:baud_generate
      baud_cnt <= baud_cnt + "1";
      if baud_cnt >= baud_value_tmp then
        baud_cnt <= (others => '0');
      end if;

      --delay_syn_ok
      syn_ok_q <= syn_ok;

      --delay_rxd
      rxd_q <= rxd;

      --go_posedge_cnt
      if (not(rxd_q) and rxd) = '1' then
        go_pos_cnt <= '1';
      elsif (not(rxd) and rxd_q) = '1' then
        go_pos_cnt <= '0';
      end if;

      --go_negedge_cnt
      if (not(rxd) and rxd_q) = '1' then
        go_neg_cnt <= '1';
      elsif (not(rxd_q) and rxd) = '1' then
        go_neg_cnt <= '0';
      end if;

      --posedge_count
      if go_pos_cnt = '1' then
        posedge_cnt <= posedge_cnt + "1";
      elsif (not(rxd_q) and rxd) = '1' then
        posedge_cnt <= (others => '0');
      end if;

      --negedge_count
      if go_neg_cnt = '1' then
        negedge_cnt <= negedge_cnt + "1";
      elsif (not(rxd) and rxd_q) = '1' then
        negedge_cnt <= (others => '0');
      end if;

      posedge_lower := posedge_cnt - shift_right(posedge_cnt,4);
      posedge_upper := posedge_cnt + shift_right(posedge_cnt,4);
      --syn_count
      if (rxd and not(rxd_q) and not(syn_ok)) = '1' then
        if (negedge_cnt > posedge_lower) and (negedge_cnt < posedge_upper) then
          syn_cnt <= syn_cnt + "1";
        else
          syn_cnt <= (others => '0');
        end if;
      end if;

      --synchronization
      if syn_cnt>=unsigned(SYN_NUM) then
        syn_ok <= '1';
      end if;

      --baudrate_value
      if (not(rxd) and rxd_q) = '1' then
        baud_value <= shift_right(posedge_cnt+negedge_cnt+"10000",4);
      end if;

      if (not(syn_ok_q) and syn_ok) = '1' then
        baud_value1 <= baud_value;
      end if;
    end if;
  end process;

end rtl;



--	////////////////////////////////////////////////////////////////////////
--	//
--	//  Abstract: Uart has an auto-tuning baud rate generator
--	//            This is an auto-tuning baud rate generator.
--	//  Module  : BAUD_GEN.v
--	//
--	//  Version : ver 01.00
--	//
--	//  Modification History:
--	//  Date By         Change Description
--	//  -----------------------------------------------------------------
--	//  2008/06/24  jackie
--	//  YYYY/MM/DD  author     Revision content
--	//
--	////////////////////////////////////////////////////////////////////////
--	`timescale 1ns/1ns
--	module BAUD_GEN
--	(
--	    rst,
--	    clk,
--	    rxd,
--	    baud_out
--	);
--	parameter   BAUD19200   = 11'd103;
--	parameter   SYN_NUM     = 8'd4;
--	parameter   SYN_OFFSET  = 8'd160;
--	parameter   delay       = 1'b1;
--	
--	input       rst;
--	input       clk;
--	input       rxd;
--	output      baud_out;
--	
--	reg  [14:0] posedge_cnt;
--	reg  [14:0] negedge_cnt;
--	reg  [14:0] baud_value;
--	reg  [10:0] baud_value1;
--	reg  [14:0] baud_cnt;
--	reg  [7:0]  syn_cnt;
--	reg         rxd_q;
--	reg         syn_ok;
--	reg         syn_ok_q;
--	reg         go_pos_cnt;
--	reg         go_neg_cnt;
--	
--	wire        rx_baudrate;
--	wire [10:0] baud_value_tmp ;
--	
--	
--	assign      baud_value_tmp = syn_ok?baud_value1:BAUD19200;
--	
--	assign      baud_out = rx_baudrate;
--	
--	assign   rx_baudrate = ((baud_cnt<=(baud_value_tmp))&&(baud_cnt>=(baud_value_tmp>>1)))?1'b1:1'b0;
--	
--	// capture a edge:baud_generate
--	always @(posedge clk)
--	begin
--	  if(rst)
--	      baud_cnt <= #delay 15'd0;
--	  else
--	    begin
--	        baud_cnt <= #delay baud_cnt+1'd1;
--	          if((baud_cnt>=(baud_value_tmp)))
--	            baud_cnt <= #delay 15'd0;
--	    end
--	end
--	
--	//delay_syn_ok
--	always @(posedge clk)
--	begin
--	  if(rst)
--	     syn_ok_q <= #delay 1'b0;
--	  else
--	     syn_ok_q <= #delay syn_ok;
--	end
--	
--	//delay_rxd
--	always @(posedge clk)
--	begin
--	  if(rst)
--	      rxd_q <= #delay 1'b1;
--	  else
--	      rxd_q <= #delay rxd;
--	end
--	
--	//go_posedge_cnt
--	always @( posedge clk)
--	begin
--	  if(rst)
--	      go_pos_cnt <= #delay 1'b0;
--	  else if((!rxd_q)&&rxd)
--	      go_pos_cnt <= #delay 1'b1;
--	  else if((!rxd)&&rxd_q)
--	      go_pos_cnt <= #delay 1'b0;
--	end
--	
--	//go_negedge_cnt
--	always @( posedge clk)
--	begin
--	  if(rst)
--	      go_neg_cnt <= #delay 1'b0;
--	  else if((!rxd)&&rxd_q)
--	      go_neg_cnt <= #delay 1'b1;
--	  else if((!rxd_q)&&rxd)
--	      go_neg_cnt <= #delay 1'b0;
--	end
--	
--	//posedge_count
--	always @(posedge clk)
--	begin
--	  if(rst)
--	      posedge_cnt <= #delay 15'd0;
--	  else if(go_pos_cnt)
--	      posedge_cnt <= #delay posedge_cnt + 15'd1;
--	  else if((!rxd_q)&&rxd)
--	      posedge_cnt <= #delay 15'd0;
--	end
--	
--	//negedge_count
--	always @( posedge clk)
--	begin
--	  if(rst)
--	      negedge_cnt <= #delay 15'd0;
--	  else if(go_neg_cnt)
--	      negedge_cnt <= #delay negedge_cnt + 15'd1;
--	  else if((!rxd)&&rxd_q)
--	      negedge_cnt <= #delay 15'd0;
--	end
--	
--	//syn_count
--	always @( posedge clk)
--	begin
--	  if(rst)
--	       syn_cnt <= #delay 7'd0;
--	  else if (rxd&&(!rxd_q)&&(!syn_ok))
--	     begin
--	       if((negedge_cnt>(posedge_cnt-SYN_OFFSET))&&(negedge_cnt<(posedge_cnt+SYN_OFFSET)))
--	            syn_cnt <= #delay syn_cnt + 7'd1;
--	       else
--	            syn_cnt <= #delay 7'd0;
--	     end
--	end
--	
--	//synchronization
--	always @(posedge clk)
--	begin
--	  if(rst)
--	       syn_ok <= #delay 1'b0;
--	  else if(syn_cnt>=SYN_NUM)
--	       syn_ok <= #delay 1'b1;
--	end
--	
--	//baudrate_value
--	always @(posedge clk)
--	begin
--	   if(rst)
--	        baud_value <= #delay 13'h1fff;
--	   else if((!rxd)&&rxd_q)
--	        baud_value <= #delay ((posedge_cnt+negedge_cnt+5'd16)>>5);
--	end
--	
--	//
--	always @(posedge clk)
--	begin
--	    if(rst)
--	        baud_value1 <= #delay BAUD19200;
--	    else if((!syn_ok_q)&&syn_ok)
--	        baud_value1 <= #delay baud_value[10:0];
--	end
--	
--	
--	endmodule ...
