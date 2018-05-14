library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

-- c2003 Franks Development, LLC
-- http://www.franks-development.com
-- !This source is distributed under the terms & conditions specified at opencores.org

--resource or companion to this code: 
	-- Xilinx Application note 12 - "Quadrature Phase Decoder" - xapp012.pdf
	-- no longer appears on xilinx website (to best of my knowledge), perhaps it has been superceeded?

--this code was origonally intended for use on Xilinx XPLA3 'coolrunner' CPLD devices
--origonally compiled/synthesized with Xilinx 'Webpack' 5.2 software

--How we 'talk' to the outside world:
entity QuadratureCounterPorts is
    Port (
     RESET : in std_logic;
     clock : in std_logic; --system clock, i.e. 10MHz oscillator
     QuadA : in std_logic; --first input from quadrature device  (i.e. optical disk encoder)
     QuadB : in std_logic; --second input from quadrature device (i.e. optical disk encoder)
     Increment_4_12 : in std_logic_vector(15 downto 0);
     SamplingInterval : in std_logic_vector(31 downto 0);
     AsyncReset : in std_logic;
     CounterValue : buffer std_logic_vector(31 downto 0);
     SpeedValue : out std_logic_vector(31 downto 0);
     SetAux1 : in std_logic;
     SetValueAux1 : in std_logic_vector(31 downto 0);
     CounterValueAux1 : buffer std_logic_vector(31 downto 0);
     SpeedValueAux1 : out std_logic_vector(31 downto 0);
     IncrementAuxTh : in std_logic_vector(63 downto 0);
     SetAuxTh : in std_logic;
     SetValueAuxTh : in std_logic_vector(63 downto 0);
     CounterValueAuxTh : buffer std_logic_vector(63 downto 0);
     SpeedValueAuxTh : out std_logic_vector(63 downto 0);
     IncrementAuxR : in std_logic_vector(63 downto 0);
     SetAuxR : in std_logic;
     SetValueAuxR : in std_logic_vector(63 downto 0);
     CounterValueAuxR : buffer std_logic_vector(63 downto 0);
     SpeedValueAuxR : out std_logic_vector(63 downto 0)
    );
end QuadratureCounterPorts;

--What we 'do':
architecture QuadratureCounter of QuadratureCounterPorts is

  -- local 'variables' or 'registers'
	
  --This is the counter for how many quadrature ticks have gone past.
  --the size of this counter is dependant on how far you need to count
  --it was origonally used with a circular disk encoder having 2048 ticks/cycle
  --thus this 16-bit count could hold 2^15 ticks in either direction, or a total
  --of 32768/2048 = 16 revolutions in either direction.  if the disk
  --was turned more than 16 times in a given direction, the counter overflows
  --and the origonal location is lost.  If you had a linear instead of 
  --circular encoder that physically could not move more than 2048 ticks,
  --then Count would only need to be 11 downto 0, and you could count
  --2048 ticks in either direction, regardless of the position of the 
  --encoder at system bootup.
  signal Count           : std_logic_vector(43 downto 0);
  signal CountAux1       : std_logic_vector(43 downto 0);
  signal Increment_32_12 : std_logic_vector(43 downto 0);
  signal CountAuxTh      : std_logic_vector(63 downto 0);
  signal CountAuxR       : std_logic_vector(63 downto 0);
	
  --this is the signal from the quadrature logic that it is time to change
  --the value of the counter on this clock signal (either + or -)
  signal CountEnable : std_logic;
	
  --should we increment or decrement count?
  signal CountDirection : std_logic;

  -- speed estimator
  signal CounterValue_old       : std_logic_vector(31 downto 0);
  signal CounterValueAux1_old   : std_logic_vector(31 downto 0);
  signal CounterValueAuxTh_old  : std_logic_vector(63 downto 0);
  signal CounterValueAuxR_old   : std_logic_vector(63 downto 0);

-- FIXME : DEBUG ++
  signal iSAMPLING_TIMER        : std_logic_vector(31 downto 0);
  signal in_QuadA               : std_logic;
  signal in_QuadB               : std_logic;
  signal in_QuadA_H_cnt         : std_logic_vector(15 downto 0);
  signal in_QuadB_H_cnt         : std_logic_vector(15 downto 0);
  signal out_QuadA              : std_logic;
  signal out_QuadB              : std_logic;
-- FIXME : DEBUG --

--where all the 'work' is done: quadraturedecoder.vhd
  component QuadratureDecoderPorts
    Port (
      clock     : in    std_logic;
      QuadA     : in    std_logic;
      QuadB     : in    std_logic;
      Direction : out std_logic;
      CountEnable : out std_logic
      );
  end component;

begin --architecture QuadratureCounter		 


-- FIXME : DEBUG ++
  timer_proc : process (RESET, clock)
    variable local_counter : integer := 0;
  begin
    if RESET = '1' then
      local_counter := 0;
      iSAMPLING_TIMER <= (others => '0');
      in_QuadA <= '0';
      in_QuadB <= '0';
      in_QuadA_H_cnt <= (others => '0');
      in_QuadB_H_cnt <= (others => '0');
      out_QuadA <= '0';
      out_QuadB <= '0';
    elsif rising_edge(clock) then
      in_QuadA <= QuadA;
      in_QuadB <= QuadB;
      if ( local_counter = 31 ) then
        iSAMPLING_TIMER <= iSAMPLING_TIMER + 1;
        local_counter := 0;
        if ( in_QuadA_H_cnt > 16 ) then
          out_QuadA <= '1';
        else
          out_QuadA <= '0';
        end if;
        if ( in_QuadB_H_cnt > 16 ) then
          out_QuadB <= '1';
        else
          out_QuadB <= '0';
        end if;
        in_QuadA_H_cnt <= (others => '0');
        in_QuadB_H_cnt <= (others => '0');
      else
        local_counter := local_counter + 1;
        if ( in_QuadA = '1' ) then
          in_QuadA_H_cnt <= in_QuadA_H_cnt + 1;
        end if;
        if ( in_QuadB = '1' ) then
          in_QuadB_H_cnt <= in_QuadB_H_cnt + 1;
        end if;
      end if;
    end if;
  end process;
-- FIXME : DEBUG --

--instanciate the decoder
  iQuadratureDecoder: QuadratureDecoderPorts 
    port map ( 
      clock => clock,
-- FIXME : DEBUG ++
--      QuadA => QuadA,
--      QuadB => QuadB,
-- FIXME : DEBUG ==
      QuadA => out_QuadA,
      QuadB => out_QuadB,
-- FIXME : DEBUG --
      Direction => CountDirection,
      CountEnable => CountEnable
      );


  -- do our actual work every clock cycle
  process(clock,RESET)
  begin
    if (RESET = '1') then
      Count <= (others => '0');
      CountAux1 <= (others => '0');
      CountAuxTh <= (others => '0');
      CountAuxR <= (others => '0');
      CounterValue <= (others => '0');
      CounterValueAux1 <= (others => '0');
      CounterValueAuxTh <= (others => '0');
      CounterValueAuxR <= (others => '0');
    elsif ( (clock'event) and (clock = '1') ) then
      if (Increment_4_12(15) = '1') then
        Increment_32_12 <= X"FFFFFFF" & Increment_4_12;
      else
        Increment_32_12 <= X"0000000" & Increment_4_12;
      end if;

      if (CountEnable = '1') then
        if (CountDirection='1') then
          Count <= Count + Increment_32_12;
        end if;
        if (CountDirection='0') then
          Count <= Count - Increment_32_12;
        end if;
      end if;
      CounterValue <= Count(43 downto 12);

      if (AsyncReset = '1') then
        CountAux1 <= (others => '0');
      elsif (SetAux1 = '1') then
        CountAux1 <= SetValueAux1 & X"000";
      else
        if (CountEnable = '1') then
          if (CountDirection='1') then
            CountAux1 <= CountAux1 + Increment_32_12;
          end if;
          if (CountDirection='0') then
            CountAux1 <= CountAux1 - Increment_32_12;
          end if;
        end if;
      end if;
      CounterValueAux1 <= CountAux1(43 downto 12);

      if (AsyncReset = '1') then
        CountAuxTh <= (others => '0');
      elsif (SetAuxTh = '1') then
        CountAuxTh <= SetValueAuxTh;
      else
        if (CountEnable = '1') then
          if (CountDirection='1') then
            CountAuxTh <= CountAuxTh + IncrementAuxTh;
          end if;
          if (CountDirection='0') then
            CountAuxTh <= CountAuxTh - IncrementAuxTh;
          end if;
        end if;
      end if;
      CounterValueAuxTh <= CountAuxTh;

      if (AsyncReset = '1') then
        CountAuxR <= (others => '0');
      elsif (SetAuxR = '1') then
        CountAuxR <= SetValueAuxR;
      else
        if (CountEnable = '1') then
          if (CountDirection='1') then
            CountAuxR <= CountAuxR + IncrementAuxR;
          end if;
          if (CountDirection='0') then
            CountAuxR <= CountAuxR - IncrementAuxR;
          end if;
        end if;
      end if;
      CounterValueAuxR <= CountAuxR;
    end if; --clock'event
  end process; --(clock)

  sampling_proc : process( clock, RESET )
    variable counter : integer := 0;
  begin
    if (RESET = '1') then
      CounterValue_old      <= (others => '0');
      CounterValueAux1_old  <= (others => '0');
      CounterValueAuxTh_old <= (others => '0');
      CounterValueAuxR_old  <= (others => '0');
      SpeedValue            <= (others => '0');
      SpeedValueAux1        <= (others => '0');
      SpeedValueAuxTh       <= (others => '0');
      SpeedValueAuxR        <= (others => '0');
      counter := 0;
    elsif ( (clock'event) and (clock = '1') ) then
      if ( counter = SamplingInterval ) then
        counter := 0;
        SpeedValue     <= CounterValue     - CounterValue_old;
        CounterValue_old     <= CounterValue;
        if (AsyncReset = '1') or (SetAux1 = '1') then
          SpeedValueAux1 <= (others => '0');
          CounterValueAux1_old <= SetValueAux1;
        else
          SpeedValueAux1 <= CounterValueAux1 - CounterValueAux1_old;
          CounterValueAux1_old <= CounterValueAux1;
        end if;
        if (AsyncReset = '1') or (SetAuxTh = '1') then
--          SpeedValueAuxTh <= (others => '0');
--          CounterValueAuxTh_old <= SetValueAuxTh;
        else
--          SpeedValueAuxTh <= CounterValueAuxTh - CounterValueAuxTh_old;
--          CounterValueAuxTh_old <= CounterValueAuxTh;
        end if;
        if (AsyncReset = '1') or (SetAuxR = '1') then
          SpeedValueAuxR <= (others => '0');
          CounterValueAuxR_old <= SetValueAuxR;
        else
          SpeedValueAuxR <= CounterValueAuxR - CounterValueAuxR_old;
          CounterValueAuxR_old <= CounterValueAuxR;
        end if;
      else
        if (AsyncReset = '1') or (SetAux1 = '1') then
          SpeedValueAux1 <= (others => '0');
          CounterValueAux1_old <= SetValueAux1;
        end if;
        if (AsyncReset = '1') or (SetAuxTh = '1') then
--          SpeedValueAuxTh <= (others => '0');
--          CounterValueAuxTh_old <= SetValueAuxTh;
        end if;
        if (AsyncReset = '1') or (SetAuxR = '1') then
          SpeedValueAuxR <= (others => '0');
          CounterValueAuxR_old <= SetValueAuxR;
        end if;
        counter := counter + 1;
      end if;
    end if;
  end process sampling_proc;
		
end QuadratureCounter;
