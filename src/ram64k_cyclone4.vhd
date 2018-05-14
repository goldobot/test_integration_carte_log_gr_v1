library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.core_config.all;
--use work.memory_pkg.all;

entity ram64k is
port(
	  clk     : in  std_logic
	; address : in  std_logic_vector(27 downto 0)
	; d       : in  std_logic_vector(31 downto 0)
	; q       : out std_logic_vector(31 downto 0)
	; ce      : in  std_logic --active low
	; we      : in  std_logic_vector(3 downto 0) --active low
	);
end entity;

architecture rtl of ram64k is

  type INIT16KX32_TYPE is array(0 to 8191) of bit_vector(31 downto 0);

  constant INIT : INIT16KX32_TYPE := (
		others => bit_vector'(X"77777777")
  );

  -- common
  signal ADD : std_logic_vector(12 downto 0);
  signal ADD_clk : std_logic_vector(12 downto 0);
  signal WEN : std_logic := '0';
  signal mem : INIT16KX32_TYPE := INIT;
 
  
begin

  ADD <= std_logic_vector(address(14 downto 2));

  WEN <= we(0) or ce;

  xilinx_gen : if CORE_TECH = xilinx generate
    xilinx_ram: process (clk)
    begin
      if falling_edge(clk) then
        if WEN = '0' then
          mem(to_integer(unsigned(ADD))) <= to_bitvector(d);
        end if;
		ADD_clk <= ADD;
      end if;
    end process;
	q <= to_stdlogicvector(mem(to_integer(unsigned(ADD_clk)))); 
  end generate;
  
end architecture;
