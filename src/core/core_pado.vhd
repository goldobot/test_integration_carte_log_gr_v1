
library ieee;
use ieee.std_logic_1164.all;

entity core_pado is
  port (
    clkm		: in	std_logic	-- clock for synchronisation

    ; dedicated	: in	std_logic	-- from special
    ; system	: in	std_logic	-- from system
    ; pad		: out	std_logic	-- to pad

    ; mode		: in	std_logic_vector(1 downto 0)
    );
end;

architecture rtl of core_pado is
  signal system0	: std_logic;
begin

  process(clkm)
  begin
    if rising_edge(clkm) then
      system0	<= system;
    end if;
  end process;

  process(mode,system0,system,dedicated)
  begin
    case mode is
      when "00" =>
        pad <= system;	-- transparent
      when "01" =>
        pad <= system0;	-- synchronized
      when "10" =>
        pad <= dedicated; -- dedicated
      when others =>
        pad <= '0';
    end case;
  end process;
end;
