library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_config.all;

entity rom_robot is
  port(
      clk     : in  std_logic
    ; address : in  std_logic_vector(27 downto 0)
    ; d       : in  std_logic_vector(31 downto 0)
    ; q       : out std_logic_vector(31 downto 0)
    ; ce      : in  std_logic --active low
    ; we      : in  std_logic_vector(3 downto 0) --active low
      );
end entity;

architecture rtl of rom_robot is

  type INITRROM_TYPE is array(0 to 255) of bit_vector(31 downto 0);

  constant INIT : INITRROM_TYPE := (
    bit_vector'(X"821020C0"),
    bit_vector'(X"81884000"),
    bit_vector'(X"81900000"),
    bit_vector'(X"09200020"),
    bit_vector'(X"03200000"),
    bit_vector'(X"8A1060D4"),
    bit_vector'(X"03200020"),
    bit_vector'(X"8C106038"),
    bit_vector'(X"03200020"),
    bit_vector'(X"8E10603C"),
    bit_vector'(X"86102000"),
    bit_vector'(X"A4102000"),
    bit_vector'(X"80A4AFFF"),
    bit_vector'(X"1480001A"),
    bit_vector'(X"01000000"),
    bit_vector'(X"E8010000"),
    bit_vector'(X"03000200"),
    bit_vector'(X"820D0001"),
    bit_vector'(X"80A06000"),
    bit_vector'(X"02800005"),
    bit_vector'(X"01000000"),
    bit_vector'(X"A6102003"),
    bit_vector'(X"10800003"),
    bit_vector'(X"01000000"),
    bit_vector'(X"A610200C"),
    bit_vector'(X"E6214000"),
    bit_vector'(X"E8018000"),
    bit_vector'(X"820D2002"),
    bit_vector'(X"80A06000"),
    bit_vector'(X"02800004"),
    bit_vector'(X"01000000"),
    bit_vector'(X"10BFFFF0"),
    bit_vector'(X"01000000"),
    bit_vector'(X"E801C000"),
    bit_vector'(X"E820C000"),
    bit_vector'(X"8600E004"),
    bit_vector'(X"A404A001"),
    bit_vector'(X"10BFFFE7"),
    bit_vector'(X"01000000"),
    bit_vector'(X"7BFFFFDC"),
    bit_vector'(X"01000000"),
    others => bit_vector'(X"01000000")
  );

  signal ADD : std_logic_vector(7 downto 0);
  signal WEN : std_logic := '0';

  signal ADD_clk : std_logic_vector(7 downto 0);
  signal WEN_clk : std_logic;

  signal mem : INITRROM_TYPE := INIT;

begin

 WEN <= we(0) or ce;
 ADD <= std_logic_vector(address(9 downto 2));

 addr_latch: process (clk)
 begin
   if falling_edge(clk) then
     if WEN = '0' then
       mem(to_integer(unsigned(ADD))) <= to_bitvector(d);
     end if;
     ADD_clk <= ADD;
   end if;
 end process;
 q <= to_stdlogicvector(mem(to_integer(unsigned(ADD_clk)))); 

end architecture;
