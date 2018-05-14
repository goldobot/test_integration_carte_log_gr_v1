
library ieee;
use ieee.std_logic_1164.all;
use work.amba.all;

package core_pad_pkg is

  constant IO_MAX : integer := 21;  -- maximum IO number
  type io_mode_type is  array (0 to IO_MAX-1) of std_logic_vector(6 downto 0);
  type io_selection_type is  array (0 to IO_MAX-1) of std_logic_vector(3 downto 0);

  component core_pad is
    port (
      clk		: in	std_logic	-- system clock
      ; rst		: in	std_logic	-- asynchronous reset
      ; testmode	: in	std_logic	-- asynchronous reset

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
  end component;

  component core_ioport is
    port (
      rst    : in  std_logic;
      clk    : in  std_logic;
      testmode : in std_logic;
      leds   : in  std_logic_vector(7 downto 0);
      debug  : in  std_logic_vector(6 downto 0);
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      mode   : out io_mode_type;
      pi     : in  std_logic_vector(IO_MAX-1 downto 0);
      pconfig: in  std_logic_vector(31 downto IO_MAX);
      po     : out std_logic_vector(IO_MAX-1 downto 0);
      pdir   : out std_logic_vector(IO_MAX-1 downto 0);
      irqout : out std_logic_vector(3 downto 0)
      );
  end component;

end;
