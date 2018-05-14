------------------------------------------------------------------
-- behavioural ram models --------------------------------------------
------------------------------------------------------------------

-- synchronous ram for direct interference

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use work.iface.all;	--no used
use work.core_config.all;
use work.target.all;
use work.config.all;
use work.tech_virtex.all;
use work.tech_virtex2.all;
use work.tech_generic.all;

entity syn_spram is
  generic (
    abits : integer := 10;
    dbits : integer := 8 );
  port (
    address  : in std_logic_vector((abits -1) downto 0);
    clk      : in std_logic;
    datain   : in std_logic_vector((dbits -1) downto 0);
    dataout  : out std_logic_vector((dbits -1) downto 0);
    enable   : in std_logic;
    write    : in std_logic
    );
end;


architecture behav of syn_spram is
begin

  inf : if INFER_RAM generate
    u0 : generic_syncram generic map (abits => abits, dbits => dbits)
      port map (address, clk , datain, dataout, enable, write);
  end generate;

  hb : if (not INFER_RAM) generate
    xcv : if TARGET_TECH = virtex generate
      u0 : virtex_syncram generic map (abits => abits, dbits => dbits)
        port map (address, clk , datain, dataout, enable, write);
    end generate;
    xc2v : if TARGET_TECH = virtex2 generate
      u0 : virtex2_syncram generic map (abits => abits, dbits => dbits)
        port map (address, clk , datain, dataout, enable, write);
    end generate;
    sim : if TARGET_TECH = gen generate
      u0 : generic_syncram generic map (abits => abits, dbits => dbits)
        port map (address, clk , datain, dataout, enable, write);
    end generate;

  end generate;
end;

-- architecture behavioral of syn_spram is

-- type mem is array(0 to (2**abits -1)) of std_logic_vector((dbits -1) downto 0);
-- signal memarr : mem;
-- signal WEN : std_logic;
-- attribute syn_ramstyle : string;
-- attribute syn_ramstyle of memarr: signal is "block_ram";
-- begin

-- syn_ram: if abits /= 8 or dbits /= 32 generate
-- main : process(clk)
-- begin
-- if rising_edge(clk) then
-- if write = '1' then
-- -- pragma translate_off
-- if not is_x(address) then
-- -- pragma translate_on
-- memarr(to_integer(unsigned(address))) <= datain;
-- -- pragma translate_off
-- end if;
-- -- pragma translate_on
-- end if;
-- -- pragma translate_off
-- if not is_x(address) then
-- -- pragma translate_on
-- dataout <= memarr(to_integer(unsigned(address)));
-- -- pragma translate_off
-- end if;
-- -- pragma translate_on
-- end if;
-- end process;
-- end generate;


-- hard_ram: if abits = 8 and dbits = 32 generate
-- WEN <= not(write);
-- st65_ram : component ST_SPREG_256x32m2_L
-- --synopsys synthesis_off
-- generic map (
-- Fault_file_name           => "ST_SPREG_256x32m2_L_faults.txt",
-- ConfigFault               => FALSE,
-- max_faults                => 20,
-- -- generics for Memory initialization
-- MEM_INITIALIZE            => FALSE,
-- BinaryInit                => 0,
-- InitFileName              => "ST_SPREG_256x32m2_L.cde",
-- Corruption_Read_Violation => TRUE,
-- Debug_mode                => "all_warning_mode",
-- InstancePath              => "ST_SPREG_256x32m2_L"
-- )
-- --synopsys synthesis_on
-- port map (
-- Q       => dataout,
-- CK      => clk,
-- CSN     => '0',
-- TBYPASS => '0',
-- WEN     => WEN,
-- A       => address(7 downto 0),
-- D       => datain
-- );
-- end generate;


-- end;
