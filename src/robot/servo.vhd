-- --========================================================================--
--
-- Module  : SERVO
--
-- ----------------------------------------------------------------------------
-- Fonction : - PWM generator for servomotor control (ex.: Futaba S3003)
--
-- --========================================================================--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity SERVO is
  port (
    -- reset & clock
    RESET              : in std_logic;
    CLK                : in std_logic;

    -- internal interface
    PWM_SERVO_PERIOD   : in std_logic_vector (31 downto 0);
    PWM_SERVO_PW       : in std_logic_vector (31 downto 0);

    -- the PWM signal 
    PWM_SERVO          : out std_logic
  );
end SERVO;

-- --============================ ARCHITECTURE ==============================--

architecture arch of SERVO is

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

signal iPWM_SERVO_PERIOD    : std_logic_vector (31 downto 0);
signal iPWM_SERVO_PW        : std_logic_vector (31 downto 0);
signal iPWM_SERVO_COUNT     : std_logic_vector (31 downto 0);
signal iPWM_SERVO           : std_logic;


begin

iRESET <= RESET;
iCLK <= CLK;

iPWM_SERVO_PERIOD <= PWM_SERVO_PERIOD;
iPWM_SERVO_PW <= PWM_SERVO_PW;
PWM_SERVO <= iPWM_SERVO;

-- SERVO pwm management
-- REM :
-- PWM_SERVO_PERIOD : std_logic_vector (31 downto 0) := X"00080000";
--  ~80 ms - 12.5 hz
p_PwmServoSM : process (iCLK, iRESET)
begin
  if (iRESET = '1') then
    iPWM_SERVO <= '0';
    iPWM_SERVO_COUNT <= (others => '0');
  elsif (iCLK'event and iCLK = '1') then
    if iPWM_SERVO_COUNT = iPWM_SERVO_PERIOD then
      iPWM_SERVO_COUNT <= (others => '0');
      if iPWM_SERVO_PW = X"00000000" then
        iPWM_SERVO <= '0';
      else
        iPWM_SERVO <= '1';
      end if;
    else
      iPWM_SERVO_COUNT <= iPWM_SERVO_COUNT + 1;
      if iPWM_SERVO_PW = iPWM_SERVO_COUNT then
        iPWM_SERVO <= '0';
      end if;
    end if;
  end if;
end process p_PwmServoSM;

end arch;

-- --================================= End ==================================--

