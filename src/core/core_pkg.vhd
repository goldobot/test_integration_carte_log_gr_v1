library ieee;
use ieee.std_logic_1164.all;

package core_pkg is

  component leon
    port(
      resetn   : in    std_logic
      ; clk      : in    std_logic
      ; pllref   : in    std_logic
      ; plllock  : out   std_logic
      ; errorn   : out   std_logic
      
      ; address  : out   std_logic_vector(27 downto 0)
      ; data_in  : in    std_logic_vector(31 downto 0)
      ; data_out : out   std_logic_vector(31 downto 0)
      ; ramsn    : out   std_logic_vector(4 downto 0)
      ; ramoen   : out   std_logic_vector(4 downto 0)
      ; rwen     : inout std_logic_vector(3 downto 0)
      ; romsn    : out   std_logic_vector(1 downto 0)
      ; iosn     : out   std_logic
      ; oen      : out   std_logic
      ; read     : out   std_logic
      ; writen   : out   std_logic
      ; brdyn    : in    std_logic
      ; bexcn    : in    std_logic
      
      ; sdcke    : out std_logic_vector ( 1 downto 0)
      ; sdcsn    : out std_logic_vector ( 1 downto 0)
      ; sdwen    : out std_logic
      ; sdrasn   : out std_logic
      ; sdcasn   : out std_logic
      ; sddqm    : out std_logic_vector ( 7 downto 0)
      ; sdclk    : out std_logic
      ; sa       : out std_logic_vector(14 downto 0)
      ; sd       : inout std_logic_vector(63 downto 0)
      
      ; pio      : in std_logic_vector(15 downto 0)
      ; wdogn    : out   std_logic
      
      ; dsuen    : in    std_logic
      ; dsutx    : out   std_logic
      ; dsurx    : in    std_logic
      ; dsubre   : in    std_logic
      ; dsuact   : out   std_logic
      
      ; test     : in    std_logic
      ; leds     : out   std_logic_vector(7 downto 0)
      ; debug    : out std_logic_vector(7 downto 0)
      ; uart_rx  : in  std_logic
      ; uart_tx  : out std_logic
      
      ; n_reset	 : in std_logic	-- reset coming from the terminal
      ; clk_dev	 : in std_logic	-- clock coming from the terminal
      ; io		 : inout std_logic	-- io port to exchange with the terminal
      );
  end component;

  component ram64k
    port(
      clk     : in  std_logic
      ; address : in  std_logic_vector(27 downto 0)
      ; d       : in  std_logic_vector(31 downto 0)
      ; q       : out std_logic_vector(31 downto 0)
      ; ce      : in  std_logic --active low
      ; we      : in  std_logic_vector(3 downto 0) --active low
      );
  end component;

  component rom32k
    port(
      clk     : in  std_logic
      ; address : in  std_logic_vector(27 downto 0)
      ; d       : in  std_logic_vector(31 downto 0) -- for debuging purpose only
      ; q       : out std_logic_vector(31 downto 0)
      ; ce      : in  std_logic --active low
      ; we      : in  std_logic_vector(3 downto 0) -- for debuging purpose only (active low)
      );
  end component;

  component rom8k
    port(
      clk     : in  std_logic
      ; address : in  std_logic_vector(27 downto 0)
      ; d       : in  std_logic_vector(31 downto 0) -- for debuging purpose only
      ; q       : out std_logic_vector(31 downto 0)
      ; ce      : in  std_logic --active low
      ; we      : in  std_logic_vector(3 downto 0) -- for debuging purpose only (active low)
      );
  end component;


end package;
