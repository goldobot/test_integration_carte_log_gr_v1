library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

entity brushless_motor is
  port(
    -- reset & clock
    RESET               : in std_logic;
    CLK                 : in std_logic;

    -- command interface
    COMMAND             : in std_logic_vector(31 downto 0);

    -- HALL interface
    HALL_GN             : in std_logic;
    HALL_BL             : in std_logic;
    HALL_GY             : in std_logic;

    -- PWM interface
    PWM_HI_BR           : out std_logic;
    PWM_LO_BR           : out std_logic;
    PWM_HI_OR           : out std_logic;
    PWM_LO_OR           : out std_logic;
    PWM_HI_YE           : out std_logic;
    PWM_LO_YE           : out std_logic;

    DEBUG               : out std_logic_vector(7 downto 0)
    );
end entity;


architecture arch of brushless_motor is

-- REM : Tpwm=10us - Fpwm=100khz (ou presque..)
constant PWM_PERIOD         : std_logic_vector (31 downto 0) := X"00000400";
constant SECURE_PWM_MAX     : std_logic_vector (31 downto 0) := X"000002f0";

signal INV_COMMAND          : std_logic_vector (31 downto 0);

signal iSENSE               : std_logic;

signal iPWM_PERIOD          : std_logic_vector (31 downto 0);
signal iPWM_H_PERIOD        : std_logic_vector (31 downto 0);

signal iPWM_COUNT           : std_logic_vector (31 downto 0);

signal iPWM_COUNT_MAX       : std_logic_vector (31 downto 0);

signal iPWM_HI              : std_logic;
signal iPWM_HI_OUT          : std_logic;
signal iPWM_LO              : std_logic;
signal iPWM_LO_OUT          : std_logic;
signal iPWM_C               : std_logic;
signal iPWM_C_OUT           : std_logic;

signal iPWM_HI_BR_P         : std_logic;
signal iPWM_LO_BR_P         : std_logic;
signal iPWM_HI_OR_P         : std_logic;
signal iPWM_LO_OR_P         : std_logic;
signal iPWM_HI_YE_P         : std_logic;
signal iPWM_LO_YE_P         : std_logic;

signal iPWM_HI_BR_N         : std_logic;
signal iPWM_LO_BR_N         : std_logic;
signal iPWM_HI_OR_N         : std_logic;
signal iPWM_LO_OR_N         : std_logic;
signal iPWM_HI_YE_N         : std_logic;
signal iPWM_LO_YE_N         : std_logic;

begin

--iPWM_LO <= '1';
iPWM_LO <= iPWM_HI;
iPWM_C <= not iPWM_HI;

iPWM_HI_OUT <= iPWM_HI;
iPWM_LO_OUT <= iPWM_LO;
iPWM_C_OUT  <= iPWM_C;

iPWM_PERIOD <= PWM_PERIOD;



iPWM_HI_BR_P <= iPWM_HI_OUT when ((HALL_GN='0') and (HALL_BL='1')) else '0';
iPWM_LO_BR_P <= iPWM_LO_OUT when ((HALL_GN='1') and (HALL_BL='0')) else
                iPWM_C_OUT;
iPWM_HI_OR_P <= iPWM_HI_OUT when ((HALL_BL='0') and (HALL_GY='1')) else '0';
iPWM_LO_OR_P <= iPWM_LO_OUT when ((HALL_BL='1') and (HALL_GY='0')) else
                iPWM_C_OUT;
iPWM_HI_YE_P <= iPWM_HI_OUT when ((HALL_GY='0') and (HALL_GN='1')) else '0';
iPWM_LO_YE_P <= iPWM_LO_OUT when ((HALL_GY='1') and (HALL_GN='0')) else
                iPWM_C_OUT;


iPWM_HI_BR_N <= iPWM_HI_OUT when ((HALL_GN='1') and (HALL_BL='0')) else '0';
iPWM_LO_BR_N <= iPWM_LO_OUT when ((HALL_GN='0') and (HALL_BL='1')) else
                iPWM_C_OUT;
iPWM_HI_OR_N <= iPWM_HI_OUT when ((HALL_BL='1') and (HALL_GY='0')) else '0';
iPWM_LO_OR_N <= iPWM_LO_OUT when ((HALL_BL='0') and (HALL_GY='1')) else
                iPWM_C_OUT;
iPWM_HI_YE_N <= iPWM_HI_OUT when ((HALL_GY='1') and (HALL_GN='0')) else '0';
iPWM_LO_YE_N <= iPWM_LO_OUT when ((HALL_GY='0') and (HALL_GN='1')) else
                iPWM_C_OUT;


PWM_HI_BR <= iPWM_HI_BR_P when (iSENSE='1') else iPWM_HI_BR_N;
PWM_LO_BR <= iPWM_LO_BR_P when (iSENSE='1') else iPWM_LO_BR_N;
PWM_HI_OR <= iPWM_HI_OR_P when (iSENSE='1') else iPWM_HI_OR_N;
PWM_LO_OR <= iPWM_LO_OR_P when (iSENSE='1') else iPWM_LO_OR_N;
PWM_HI_YE <= iPWM_HI_YE_P when (iSENSE='1') else iPWM_HI_YE_N;
PWM_LO_YE <= iPWM_LO_YE_P when (iSENSE='1') else iPWM_LO_YE_N;


INV_COMMAND <= X"00000000" - COMMAND;

-- pwm management
-- REM :
-- PWM_PERIOD : std_logic_vector (31 downto 0) := X"00000400"; -- 10us - 100khz
p_PwmSM : process (CLK, RESET)
begin
  if (RESET = '1') then
    iPWM_HI <= '0';
    iPWM_COUNT <= (others => '0');
    iPWM_COUNT_MAX <= (others => '0');
    iPWM_H_PERIOD <= (others => '0');
    iSENSE <= '1';
  elsif (CLK'event and CLK = '1') then
    if COMMAND(31) = '1' then
      iPWM_H_PERIOD <= X"00000" & INV_COMMAND (11 downto 0);
      iSENSE <= '0';
    else
      iPWM_H_PERIOD <= X"00000" & COMMAND (11 downto 0);
      iSENSE <= '1';
    end if;
    if iPWM_H_PERIOD > SECURE_PWM_MAX then
      iPWM_COUNT_MAX <= SECURE_PWM_MAX;
    else
      iPWM_COUNT_MAX <= iPWM_H_PERIOD;
    end if;
    if iPWM_COUNT = iPWM_PERIOD then
      iPWM_COUNT <= (others => '0');
      if iPWM_COUNT_MAX = X"00000000" then
        iPWM_HI <= '0';
      else
        iPWM_HI <= '1';
      end if;
    else
      iPWM_COUNT <= iPWM_COUNT + 1;
      if iPWM_COUNT_MAX = iPWM_COUNT then
        iPWM_HI <= '0';
      end if;
    end if;
  end if;
end process p_PwmSM;


end arch;



