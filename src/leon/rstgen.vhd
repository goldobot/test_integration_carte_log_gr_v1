



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
-- Entity:   rstgen
-- File:  rstgen.vhd
-- Author:  Jiri Gaisler - ESA/ESTEC
-- Description:  Reset generation for both processor and PCI interface. Reset
--    is generated for 4 extra clock after external reset has been
--    de-asserted.

------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.config.all;
use work.iface.all;
use work.core_config.all;

entity rstgen is
  port (
    rstin     : in  std_logic;
    clk       : in  clk_type;
    rstout    : out std_logic;
    cgo       : in  clkgen_out_type
    );
end;

architecture rtl of rstgen is
  signal r, rin : std_logic_vector(4 downto 0);
  signal reset : std_logic;
  signal rst : std_logic;

begin

  reset <= rstin;

-- processor reset generation
  reg1 : process (clk,reset)
  begin
    if reset = '0' then r <= "00000"; rst <= '0';
    elsif rising_edge(clk) then
      r <= r(3 downto 0) & cgo.clklock;
      rst <= r(4) and r(3) and r(2);
    end if;
  end process;

  no_start_reset_tree: if CORE_TECH = xilinx generate
    rstout <= rst;
  end generate;

end;
