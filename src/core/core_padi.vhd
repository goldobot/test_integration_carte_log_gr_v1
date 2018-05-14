
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.core_config.all;

entity core_padi is
  port (
    clk		: in	std_logic	-- system clock
    ; clkm		: in	std_logic	-- clock for synchronisation

    ; rst		: in	std_logic	-- asynchronous reset

    ; pad		: in	std_logic	-- from pad
    ; system	: out	std_logic	-- to system

    ; mode		: in	std_logic
    );
end;

architecture rtl of core_padi is
  signal pad0	: std_logic;
  signal pad1	: std_logic;
  signal pad2	: std_logic;
  signal pad1_sys	: std_logic;
  signal pad2_sys	: std_logic;
begin

  no_delay: if CORE_TECH = xilinx generate
    pad0 <= pad;
  end generate;

  process(clkm)
  begin
    if rising_edge(clkm) then
      pad1	<= pad0;
      pad2	<= pad1;
    end if;
  end process;
  process(clk)
  begin
    if rising_edge(clk) then
      pad1_sys <= pad2;
    end if;
  end process;
  -- add half clock period: prevent C3_clk setup and hold violations
  process(clk)
  begin
    if falling_edge(clk) then
      pad2_sys <= pad1_sys;
    end if;
  end process;

  process(mode,pad0,pad1_sys,pad2_sys)
  begin
    if mode = '0' then
      system <= pad0;	-- transparent
    else
      system <= pad2_sys;	-- non metastable and synchronized
    end if;
  end process;

end;
