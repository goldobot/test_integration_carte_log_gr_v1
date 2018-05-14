-- --========================================================================--
--
-- Module  : ULTRASOUND_HCSR04
--
-- ----------------------------------------------------------------------------
-- Fonction : - Interface for HC-SR04 ultrasound module
--
-- --========================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ULTRASOUND_HCSR04 is
  port (
    -- reset & clock
    RESET          : in std_logic;
    CLK            : in std_logic; -- the clock should be @ 25MHz

    -- internal interface
    ACTUAL_DIST    : out std_logic_vector (31 downto 0);

    -- external interface
    US_PULSE       : out std_logic;
    US_RESPONSE    : in std_logic
  );
end ULTRASOUND_HCSR04;


-- --============================ ARCHITECTURE ==============================--

architecture arch of ULTRASOUND_HCSR04 is

-- ----------------------------------------------------------------------------
-- Component declarations
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Constant declarations
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Signal declarations
-- ----------------------------------------------------------------------------

signal iACTUAL_DIST         : std_logic_vector (31 downto 0);
signal iUS_RESPONSE1        : std_logic;
signal iUS_RESPONSE2        : std_logic;

begin


p_PulseSM : process (CLK, RESET)
  variable local_counter : integer := 0;
  variable counting : std_logic := '0';
begin
  if (RESET = '1') then
    local_counter := 0;
    counting := '0';
    iUS_RESPONSE1 <= '0';
    iUS_RESPONSE2 <= '0';
    iACTUAL_DIST <= (others => '0');
    ACTUAL_DIST <= (others => '0');
    US_PULSE <= '0';
  elsif (CLK'event and CLK = '1') then
    if ( local_counter = 124999 ) then
      local_counter := 0;
      counting := '0';
      ACTUAL_DIST <= iACTUAL_DIST;
      iACTUAL_DIST <= (others => '0');
      US_PULSE <= '1';
    else
      if ( local_counter = 250 ) then
        US_PULSE <= '0';
      end if;
      if ( local_counter > 255 ) then
        if ( (iUS_RESPONSE2='0') and (iUS_RESPONSE1='1') ) then
          counting := '1';
        elsif ( (iUS_RESPONSE2='1') and (iUS_RESPONSE1='0') ) then
          counting := '0';
        end if;
      end if;
      if ( counting = '1' ) then
        iACTUAL_DIST <= iACTUAL_DIST + 1;
      end if;
      local_counter := local_counter + 1;
    end if;
    iUS_RESPONSE2 <= iUS_RESPONSE1;
    iUS_RESPONSE1 <= US_RESPONSE;
  end if;
end process p_PulseSM;

end arch;

-- --================================= End ==================================--

