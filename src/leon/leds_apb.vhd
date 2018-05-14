library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--pragma translate_off
use work.debug.all;
--pragma translate_on

entity leds_apb is
  port( pclk    : in  std_logic
	; presetn : in  std_logic
	; paddr   : in  std_logic_vector(31 downto 0)
	; psel    : in  std_logic
	; penable : in  std_logic
	; pwrite  : in  std_logic
	; pwdata  : in  std_logic_vector(31 downto 0)
	; prdata  : out std_logic_vector(31 downto 0)
	; leds    : out std_logic_vector( 7 downto 0) -- 8 LEDS
	);
end entity;

architecture rtl of leds_apb is
  signal leds_s : std_logic_vector( 7 downto 0);
begin

  leds <= leds_s;

-- Write process
  write_proc : process (presetn, pclk)
  begin
    if presetn = '0' then
      leds_s <= (others => '1'); -- Light on
    elsif rising_edge(pclk) then
      if (psel = '1') and (penable = '1') and (pwrite = '1') then
        case paddr(3 downto 2) is
          when "01" => -- 0x800000D4
            leds_s <= pwdata(7 downto 0); -- 1 in leds is light on
          when "10" => -- 0x800000D8
          when "11" => -- 0x800000DC
          when "00" => -- 0x800000D0
          when others =>
        end case;
      end if;
    end if;
  end process;
  
-- Read process
  read_proc : process(presetn, psel, penable, pwrite, leds_s)
  begin
    if presetn = '0' then
      prdata <= (others => '1');
    elsif (psel = '1') and (penable = '1') and (pwrite = '0') then
      prdata <= leds_s & leds_s & leds_s & leds_s;
    else
      prdata <= (others => '1');
    end if;
  end process;


end architecture;
