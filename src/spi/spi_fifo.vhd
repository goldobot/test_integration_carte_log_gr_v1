--///////////////////////////////////////////////////////////////////
--//                                                             ////
--// FIFO 4 entries deep                                         ////
--//                                                             ////
--///////////////////////////////////////////////////////////////////

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- 4 entry deep fast fifo
entity spi_fifo is
  generic (
    DATAWIDTH : natural := 8
    );
  port (
    clk	: in std_logic
    ; rst	: in std_logic
    ; clr	: in std_logic
    ; din	: in std_logic_vector(DATAWIDTH-1 downto 0)
    ; we	: in std_logic
    ; dout	: out std_logic_vector(DATAWIDTH-1 downto 0)
    ; re	: in std_logic
    ; full	: out std_logic
    ; empty	: out std_logic
    );
end;

architecture rtl of spi_fifo is

--//////////////////////////////////////////////////////////////////
--
-- Local Wires
--
  type mem_type is array(natural range 0 to 3) of std_logic_vector(DATAWIDTH-1 downto 0);

  signal mem	: mem_type;
  signal wp	: unsigned(1 downto 0);
  signal wp_p1	: unsigned(1 downto 0);
  signal wp_p2	: unsigned(1 downto 0);
  signal rp	: unsigned(1 downto 0);
  signal rp_p1	: unsigned(1 downto 0);
  signal gb	: std_logic;


begin

--//////////////////////////////////////////////////////////////////
--
-- Misc Logic
--

  process(rst,clk)
  begin
    if rst = '0' then
      wp <= "00";
    elsif rising_edge(clk) then
      if clr = '1' then
        wp <= "00";
      elsif we = '1' then
        wp <= wp_p1;
      end if;
    end if;
  end process;
  wp_p1 <= wp + "01";
  wp_p2 <= wp + "10";

  process(rst,clk)
  begin
    if rst = '0' then
      rp <= "00";
    elsif rising_edge(clk) then
      if clr = '1' then
        rp <= "00";
      elsif re = '1' then
        rp <= rp_p1;
      end if;
    end if;
  end process;
  rp_p1 <= rp + "01";

-- Fifo Output
  process(mem,rp)
  begin
--pragma translate_off
    if not is_x(std_logic_vector(rp)) then
--pragma translate_on
      dout <= mem(to_integer(rp));
--pragma translate_off
    else
      dout <= (others => 'X');
    end if;
--pragma translate_on
  end process;

-- Fifo Input
  process(clk,rst)
  begin
    if rst = '0' then
      mem(0) <= (others => '0');
      mem(1) <= (others => '0');
      mem(2) <= (others => '0');
      mem(3) <= (others => '0');
    elsif rising_edge(clk) then
      if we = '1' then
--pragma translate_off
        if not is_x(std_logic_vector(wp)) then
--pragma translate_on
          mem(to_integer(wp)) <= din;
--pragma translate_off
        end if;
--pragma translate_on
      end if;
    end if;
  end process;

-- Status
  process(wp,rp,gb)
  begin
    if (wp = rp) and (gb = '0') then
      empty <= '1';
    else
      empty <= '0';
    end if;
    if (wp = rp) and (gb = '1') then
      full <= '1';
    else
      full <= '0';
    end if;
  end process;

-- Guard Bit ...
  process(rst,clk)
  begin
    if rst = '0' then
      gb <= '0';
    elsif rising_edge(clk) then
      if clr = '1' then
        gb <= '0';
      elsif (wp_p1 = rp ) and (we = '1') then
        gb <= '1';
      elsif (re = '1') then
        gb <= '0';
      end if;
    end if;
  end process;

end rtl;
