library ieee;
use ieee.std_logic_1164.all;

package core_config is

  type core_techs is (gen, xilinx, altera, ams35, st65, st65beh);
  constant CORE_TECH : core_techs := xilinx;

end package;
