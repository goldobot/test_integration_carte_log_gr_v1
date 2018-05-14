



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
-- Entity: 	dsu_mem
-- File:	dsu_mem.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	DSU trace buffer memory
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.target.all;
use work.config.all;
use work.iface.all;
use worK.tech_map.all;

entity dsu_mem is
  port (
    clk    : in  clk_type;
    dmi    : in  dsumem_in_type;
    dmo    : out dsumem_out_type
    );
end;

architecture rtl of dsu_mem is

  component syn_spram
    generic ( abits : integer := 10; dbits : integer := 8 );
    port (
      address  : in std_logic_vector((abits -1) downto 0);
      clk      : in std_logic;
      datain   : in std_logic_vector((dbits -1) downto 0);
      dataout  : out std_logic_vector((dbits -1) downto 0);
      enable   : in std_logic;
      write    : in std_logic
      );
  end component;

begin

  nomix : if DSUTRACE and not DSUMIXED generate
    spram0 : if not DSUDPRAM generate
      mem0 : for i in 0 to 3 generate
        ram0 : component syn_spram
          generic map ( dbits => 32, abits => TBUFABITS)
          port map ( dmi.pbufi.addr(TBUFABITS-1 downto 0), clk,
                     dmi.pbufi.data(((i*32)+31) downto (i*32)),
                     dmo.pbufo.data(((i*32)+31) downto (i*32)), dmi.pbufi.enable, dmi.pbufi.write(i));
      end generate;
    end generate;
    dpram0 : if DSUDPRAM generate
      mem0 : for i in 0 to 1 generate
        ram0 : dpsyncram generic map ( dbits => 32, abits => TBUFABITS+1)
          port map ( dmi.pbufi.addr(TBUFABITS downto 0), clk,
                     dmi.pbufi.data(((i*32)+31) downto (i*32)),
                     dmo.pbufo.data(((i*32)+31) downto (i*32)), dmi.pbufi.enable, dmi.pbufi.write(i),
                     dmi.abufi.addr(TBUFABITS downto 0), clk,
                     dmi.pbufi.data(((i*32)+31+64) downto (i*32+64)),
                     dmo.pbufo.data(((i*32)+31+64) downto (i*32+64)), dmi.pbufi.enable,
                     dmi.pbufi.write(i+2));
      end generate;
    end generate;
  end generate;

  tbmix : if DSUTRACE and DSUMIXED generate
    spram0 : if not DSUDPRAM generate
      mem0 : for i in 0 to 3 generate
        ram0 : component syn_spram
          generic map ( dbits => 32, abits => TBUFABITS-1)
          port map ( dmi.pbufi.addr(TBUFABITS-2 downto 0), clk,
                     dmi.pbufi.data(((i*32)+31) downto (i*32)),
                     dmo.pbufo.data(((i*32)+31) downto (i*32)),
                     dmi.pbufi.enable, dmi.pbufi.write(i));
      end generate;
      mem1 : for i in 0 to 3 generate
        ram0 : component syn_spram
          generic map ( dbits => 32, abits => TBUFABITS-1)
          port map ( dmi.abufi.addr(TBUFABITS-2 downto 0), clk,
                     dmi.abufi.data(((i*32)+31) downto (i*32)),
                     dmo.abufo.data(((i*32)+31) downto (i*32)),
                     dmi.abufi.enable, dmi.abufi.write(i));
      end generate;
    end generate;
    dpram0 : if DSUDPRAM generate
      mem0 : for i in 0 to 3 generate
        ram0 : dpsyncram generic map ( dbits => 32, abits => TBUFABITS)
          port map ( dmi.pbufi.addr(TBUFABITS-1 downto 0), clk,
                     dmi.pbufi.data(((i*32)+31) downto (i*32)),
                     dmo.pbufo.data(((i*32)+31) downto (i*32)),
                     dmi.pbufi.enable, dmi.pbufi.write(i),
                     dmi.abufi.addr(TBUFABITS-1 downto 0), clk,
                     dmi.abufi.data(((i*32)+31) downto (i*32)),
                     dmo.abufo.data(((i*32)+31) downto (i*32)),
                     dmi.abufi.enable, dmi.abufi.write(i));
      end generate;
    end generate;
  end generate;

end;
