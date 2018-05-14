-- --========================================================================--
--
-- Module  : PUMP
--
-- ----------------------------------------------------------------------------
-- Fonction : - PWM generator for pump control
--
-- --========================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity PUMP is
  port (
    -- reset & clock
    RESET              : in std_logic;
    CLK                : in std_logic;

    -- internal interface
    PWM_PUMP_PERIOD    : in std_logic_vector (31 downto 0);
    PWM_PUMP_PW        : in std_logic_vector (31 downto 0);

    -- the PWM signal 
    PWM_PUMP           : out std_logic
  );
end PUMP;

-- --============================ ARCHITECTURE ==============================--

architecture arch of PUMP is

-- ----------------------------------------------------------------------------
-- Component declarations
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Constant declarations
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- Signal declarations
-- ----------------------------------------------------------------------------
signal iRESET               : std_logic;
signal iCLK                 : std_logic;

signal iPWM_PUMP_PERIOD     : std_logic_vector (31 downto 0);
signal iPWM_PUMP_PW_MAX     : std_logic_vector (31 downto 0);
signal iPWM_COUNT_PUMP      : std_logic_vector (31 downto 0);
signal iPWM_PUMP            : std_logic;


begin

iRESET <= RESET;
iCLK <= CLK;

iPWM_PUMP_PERIOD <= PWM_PUMP_PERIOD;
PWM_PUMP <= iPWM_PUMP;

p_PwmPumpSM : process (iCLK, iRESET)
begin
  if (iRESET = '1') then
    iPWM_PUMP <= '0';
    iPWM_COUNT_PUMP <= (others => '0');
    iPWM_PUMP_PW_MAX <= (others => '0');
  elsif (iCLK'event and iCLK = '1') then
-- FIXME : TODO : limite arbitraire..
    if PWM_PUMP_PW > X"000003FF" then
      iPWM_PUMP_PW_MAX <= X"000003FF";
    else
      iPWM_PUMP_PW_MAX <= PWM_PUMP_PW;
    end if;
    if iPWM_COUNT_PUMP = iPWM_PUMP_PERIOD then
      iPWM_COUNT_PUMP <= (others => '0');
      if iPWM_PUMP_PW_MAX = X"00000000" then
        iPWM_PUMP <= '0';
      else
        iPWM_PUMP <= '1';
      end if;
    else
      iPWM_COUNT_PUMP <= iPWM_COUNT_PUMP + 1;
      if iPWM_PUMP_PW_MAX = iPWM_COUNT_PUMP then
        iPWM_PUMP <= '0';
      end if;
    end if;
  end if;
end process p_PwmPumpSM;

end arch;

-- --================================= End ==================================--

