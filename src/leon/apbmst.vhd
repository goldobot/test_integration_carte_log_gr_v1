



----------------------------------------------------------------------------
--  This file is a part of the LEON VHDL model
--  Copyright (C) 1999  European Space Agency (ESA)
--
--  This library is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Lesser General Public
--  License as published by the Free Software Foundation; either
--  version 2 of the License, or (at your option) any later version.
--
--  See the file COPYING.LGPL for the full details of the license.


-----------------------------------------------------------------------------
-- Entity:      apbmst
-- File:        apbmst.vhd
-- Author:      Jiri Gaisler - ESA/ESTEC
-- Description: AMBA AHB/APB bridge
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use work.target.all;
use work.config.all;
use work.iface.all;
use work.amba.all;


entity apbmst is
  generic (apbmax : integer := 15);
  port (
    rst  : in  std_logic;
    clk  : in  clk_type;
    ahbi : in  ahb_slv_in_type;
    ahbo : out ahb_slv_out_type;
    apbi : out apb_slv_in_vector(0 to APB_SLV_MAX-1);
    apbo : in  apb_slv_out_vector(0 to APB_SLV_MAX-1)
    );
end;

architecture rtl of apbmst is

-- registers
  type reg_type is record
    haddr   : std_logic_vector(15 downto 2);  -- address bus
    hwdata  : std_logic_vector(31 downto 0);  -- write data
    hrdata  : std_logic_vector(31 downto 0);  -- read data
    hsel    : std_logic;
    hwrite  : std_logic;                      -- read/write
    hready  : std_logic;                      -- ready
    psel    : std_logic;
    penable : std_logic;
  end record;

  signal r, rin : reg_type;

begin
  comb : process(ahbi, apbo, r, rst)
    variable v        : reg_type;
    variable psel     : std_logic_vector(0 to APB_SLV_MAX-1);
    variable prdata   : std_logic_vector(31 downto 0);
    variable pwdata   : std_logic_vector(31 downto 0);
    variable apbaddr  : std_logic_vector(10 downto 2);
    variable apbaddr2 : std_logic_vector(31 downto 0);
    variable msbaddr  : std_logic_vector(1 downto 0);
    variable bindex   : integer range 0 to APB_SLV_MAX-1;
    variable esel     : std_logic;
  begin

    v := r;

    -- detect start of cycle
    if (ahbi.hready = '1') then
      if ((ahbi.htrans = HTRANS_NONSEQ) or (ahbi.htrans = HTRANS_SEQ)) and
        (ahbi.hsel = '1')
      then
        v.hready                 := '0'; v.hwrite := ahbi.hwrite; v.hsel := '1';
        v.hwrite                 := ahbi.hwrite;
        v.haddr(apbmax downto 2) := ahbi.haddr(apbmax downto 2);
      else v.hsel := '0'; end if;
    end if;

    if r.hsel = '1' then v.hwdata  := ahbi.hwdata; v.psel := '1'; end if;
    if r.psel = '1' then v.penable := '1'; end if;
    if r.penable = '1' then
      v.penable := '0'; v.psel := '0'; v.hready := '1'; v.hsel := '0';
    end if;

    -- generate psel and select APB read data
    psel    := (others => '0'); prdata := (others => '-');
    apbaddr := r.haddr(10 downto 2);
    msbaddr := r.haddr(apbmax downto apbmax-1);
    bindex  := 0; esel := '0';

    case msbaddr is

      when "00" =>
        case apbaddr is
          when "000000000" | "000000001" | "000000010" =>
            esel := '1'; bindex := 0;   -- memory controller, 0x00 - 0x08
          when "000000011" | "000000100" =>
            esel := '1'; bindex := 1;   -- AHB status reg.,   0x0C - 0x10
          when "000000101" | "000000110" =>
            esel := '1'; bindex := 2;   -- cache controller,  0x14 - 0x18
          when "000000111" | "000001000" =>
            -- write protection,  0x1C - 0x20
            if WPROTEN then esel := '1'; bindex := 3; end if;
          when "000001001" =>
            -- config register,   0x24 - 0x24
            if CFGREG then esel := '1'; bindex := 4; end if;
          when "000010000" | "000010001" | "000010010" | "000010011" |
            "000010100" | "000010101" | "000010110" | "000010111" |
            "000011000" | "000011001" | "000011010" | "000011011" =>
            esel := '1'; bindex := 5;   -- timers,            0x40 - 0x6C
          when "000011100" | "000011101" | "000011110" | "000011111" =>
            esel := '1'; bindex := 6;   -- uart1,             0x70 - 0x7C
          when "000100000" | "000100001" | "000100010" | "000100011" =>
            esel := '1'; bindex := 7;   -- uart2,             0x80 - 0x8C
          when "000100100" | "000100101" | "000100110" | "000100111" =>
            esel := '1'; bindex := 8;   -- interrupt ctrl     0x90 - 0x9C
          when "000101000" | "000101001" | "000101010" | "000101011" =>
            esel := '1'; bindex := 9;   -- I/O port           0xA0 - 0xAC
          when "000101100" | "000101101" | "000101110" | "000101111" =>
            -- 2nd interrupt ctrl 0xB0 - 0xBC
            if IRQ2EN then esel := '1'; bindex := 10; end if;
          when "000110000" | "000110001" | "000110010" | "000110011" =>
            -- DSU uart           0xC0 - 0xCC
            if DEBUG_UNIT then esel := '1'; bindex := 11; end if;
          when "000110100" =>
            if PCIEN then               -- PCI target mapping 0x0D0
              esel := '1'; bindex := 12;
            end if;
          when "000110101" | "000110110" | "000110111" | "000111000" =>
            esel := '1'; bindex := 14;  -- LEDS 0xD4 - 0xD8 - 0xDC - 0xE0
          when others =>
            if PCIEN and (apbaddr(10 downto 8) = "001") then
              esel := '1'; bindex := 12;             -- 0x100 - 0x200
            end if;
            if PCIARBEN and (r.haddr(10 downto 8) = "010") then
              esel := '1'; bindex := 13;             -- 0x200 - 0x300
            end if;
        end case;

      when "01" =>
        -- Goldo components
        case apbaddr(10 downto 7) is
          when "0000" =>  -- <available> [0x80004000 - 0x8000407F]
            esel := '1'; bindex := 15;
          when "0001" =>  -- <available> [0x80004080 - 0x800040FF]
            esel := '1'; bindex := 16;
          when "0010" =>  -- <available> [0x80004100 - 0x8000417F]
            esel := '1'; bindex := 17;
          when "0011" =>  -- <available> [0x80004180 - 0x800041FF]
            esel := '1'; bindex := 18;
          when "0100" =>  -- <available> [0x80004200 - 0x8000427F]
            esel := '1'; bindex := 19;
          when "0101" =>  -- <available> [0x80004280 - 0x800042FF]
            esel := '1'; bindex := 20;
          when "0110" =>  -- <available> [0x80004300 - 0x8000437F]
            esel := '1'; bindex := 21;
          when "0111" =>  -- i2c0        [0x80004380 - 0x800043FF]
            esel := '1'; bindex := 22;
          when "1000" =>  -- i2c1        [0x80004400 - 0x8000447F]
            esel := '1'; bindex := 23;
          when "1001" =>  -- <available> [0x80004480 - 0x800044FF]
            esel := '1'; bindex := 24;
          when "1010" =>  -- <available> [0x80004500 - 0x8000457F]
            esel := '1'; bindex := 25;
          when "1011" =>  -- spi         [0x80004580 - 0x800045FF]
            esel := '1'; bindex := 26;
          when others =>
            esel := '1'; bindex := 26;
        end case;

      when "10" =>  -- GOLDO ROBOT [0x80008000 - 0x8000BFFF]
        esel := '1'; bindex := 27;

      when others =>
        if PCIEN and (r.haddr(apbmax downto apbmax-1) /= "00") then
          esel := '1'; bindex := 12;    -- 0x4000 - 0xFFFC
        end if;
    end case;

    prdata   := apbo(bindex).prdata; psel(bindex) := esel;
    v.hrdata := prdata;

--    for i in APB_TABLE'range loop     --'
--      if  APB_TABLE(i).enable and
--       (apbaddr >= APB_TABLE(i).firstaddr(apbmax downto 2)) and
--         (apbaddr <= APB_TABLE(i).lastaddr(apbmax downto 2))
--      then
--      prdata := apbo(APB_TABLE(i).index).prdata;
--      psel(APB_TABLE(i).index) := '1';
--      end if;
--    end loop;

    -- AHB respons
    ahbo.hresp  <= HRESP_OKAY;
    ahbo.hready <= r.hready;
    ahbo.hrdata <= r.hrdata;
    ahbo.hsplit <= (others => '0');

    if rst = '0' then
      v.penable := '0'; v.hready := '1'; v.hsel := '0'; v.psel := '0'; v.hwrite := '0';
-- pragma translate_off
      v.haddr   := (others => '0');
-- pragma translate_on
    end if;

    rin <= v;

    -- drive APB bus
    apbaddr2                  := (others => '0');
    apbaddr2(apbmax downto 2) := r.haddr(apbmax downto 2);
    for i in 0 to APB_SLV_MAX-1 loop
      apbi(i).paddr   <= apbaddr2;
      apbi(i).pwdata  <= r.hwdata;
      apbi(i).pwrite  <= r.hwrite;
      apbi(i).penable <= r.penable;
      apbi(i).psel    <= psel(i) and r.psel;
    end loop;

  end process;


  reg : process(clk)
  begin if rising_edge(clk) then r <= rin; end if; end process;


end;
