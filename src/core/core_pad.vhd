
library ieee;
use ieee.std_logic_1164.all;

entity core_pad is
  port (
    clk		: in	std_logic	-- system clock
    ; rst		: in	std_logic	-- asynchronous reset
    ; testmode	: in	std_logic	-- test mode: normal mode when '0'

    ; mode		: in	std_logic_vector(6 downto 0)

    -- output
    ; o_dedicated	: in	std_logic	-- from special
    ; o_system	: in	std_logic	-- from system
    ; o_pad		: out	std_logic	-- to pad

    -- enable
    ; en_dedicated	: in	std_logic	-- from special
    ; en_system	: in	std_logic	-- from system
    ; en_pad	: out	std_logic	-- to pad

    -- input
    ; i_pad		: in	std_logic	-- from pad
    ; i_system	: out	std_logic	-- to system
    );
end;


architecture rtl of core_pad is

  component core_padi is
    port (
      clk		: in	std_logic	-- system clock
      ; clkm		: in	std_logic	-- clock for synchronisation

      ; rst		: in	std_logic	-- asynchronous reset

      ; pad		: in	std_logic	-- from pad
      ; system	: out	std_logic	-- to system

      ; mode		: in	std_logic
      );
  end component;

  component core_pado is
    port (
      clkm		: in	std_logic	-- clock for synchronisation

      ; dedicated	: in	std_logic	-- from special
      ; system	: in	std_logic	-- from system
      ; pad		: out	std_logic	-- to pad

      ; mode		: in	std_logic_vector(1 downto 0)
      );
  end component;

  signal	io_clkm	: std_logic;
  signal	en_clkm	: std_logic;
  signal  en_pad_wo_testmode : std_logic;

begin

  o : core_pado
    port map (
      clkm => clk
      , dedicated => o_dedicated
      , system => o_system
      , pad => o_pad
      , mode => mode(1 downto 0)
      );

  en : core_pado
    port map (
      clkm => clk
      , dedicated => en_dedicated
      , system => en_system
      , pad => en_pad_wo_testmode
      , mode => mode(3 downto 2)
      );
  en_pad <= en_pad_wo_testmode when testmode = '0' else '1'; -- pad is 'Z' when test mode activate

  i : core_padi
    port map (
      clk => clk
      , clkm => clk
      , rst => rst
      , pad => i_pad
      , system => i_system
      , mode => mode(4)
      );

--	io_clkm	<= clk xor mode(5);
--	en_clkm	<= clk xor mode(6);

end architecture;
