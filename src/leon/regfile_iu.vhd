LIBRARY ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.target.all;
use work.config.all;
use work.iface.all;
use work.core_config.all;

entity regfile_iu is
  generic (
    abits : integer := 8;
    dbits : integer := 32;
    words : integer := 128
    );
  port (
    rst      : in std_logic;
    clk      : in clk_type;
    clkn     : in clk_type;
    rfi      : in rf_in_type;
    rfo      : out rf_out_type);
end;

architecture rtl of regfile_iu is
  type dregtype is array (0 to words - 1) of std_logic_vector(dbits -1 downto 0);
  signal rfd1 : dregtype;
  signal rfd2 : dregtype;
-- pragma translate_off
  attribute syn_ramstyle1 : string;
  attribute syn_ramstyle2 : string;
  attribute syn_ramstyle1 of rfd1: signal is "block_ram";
  attribute syn_ramstyle2 of rfd2: signal is "block_ram";
-- pragma translate_on
  signal WEN : std_logic;

begin

  xilinx_gen : if CORE_TECH = xilinx generate
    rp1 : process(clkn)
    begin
      if rising_edge(clkn) then
        if rfi.wren = '1' then
-- pragma translate_off
          if not ( is_x(rfi.wraddr) or (to_integer(unsigned(rfi.wraddr)) >= words))
          then
-- pragma translate_on
            rfd1(to_integer(unsigned(rfi.wraddr))) <= rfi.wrdata;
-- pragma translate_off
          end if;
-- pragma translate_on
        end if;
      end if;
    end process;
-- pragma translate_off

    comb1 : process(rfi, rfd1)
    begin
      if not (is_x(rfi.rd1addr) or (to_integer(unsigned(rfi.rd1addr)) >= words))
      then
-- pragma translate_on
        rfo.data1 <= rfd1(to_integer(unsigned(rfi.rd1addr)));
-- pragma translate_off
      else
        rfo.data1 <= (others => 'X');
      end if;
    end process;
-- pragma translate_on


    rp2 : process(clkn)
    begin
      if rising_edge(clkn) then
        if rfi.wren = '1' then
-- pragma translate_off
          if not ( is_x(rfi.wraddr) or (to_integer(unsigned(rfi.wraddr)) >= words))
          then
-- pragma translate_on
            rfd2(to_integer(unsigned(rfi.wraddr))) <= rfi.wrdata;
-- pragma translate_off
          end if;
-- pragma translate_on
        end if;
      end if;
    end process;
-- pragma translate_off

    comb2 : process(rfi, rfd2)
    begin
      if not (is_x(rfi.rd2addr) or (to_integer(unsigned(rfi.rd2addr)) >= words))
      then
-- pragma translate_on
        rfo.data2 <= rfd2(to_integer(unsigned(rfi.rd2addr)));
-- pragma translate_off
      else
        rfo.data2 <= (others => 'X');
      end if;
    end process;
-- pragma translate_on
  end generate;

end;
