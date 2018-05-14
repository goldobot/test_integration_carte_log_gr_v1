library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;


entity robot_gps_odo is
  port (
    clock_i        : in std_logic;
    resetb_i       : in std_logic;

    ENABLE         : in std_logic;
    SETUP          : in std_logic;

    GPS_X_INIT     : in std_logic_vector(63 downto 0);
    GPS_Y_INIT     : in std_logic_vector(63 downto 0);
    GPS_THETA_INIT : in std_logic_vector(63 downto 0);

    QUAD_CNT_TH_R  : in std_logic_vector(63 downto 0);
    QUAD_CNT_R_R   : in std_logic_vector(63 downto 0);

    QUAD_CNT_TH_L  : in std_logic_vector(63 downto 0);
    QUAD_CNT_R_L   : in std_logic_vector(63 downto 0);

    MUL64_OP1      : out std_logic_vector(63 downto 0);
    MUL64_OP2      : out std_logic_vector(63 downto 0);
    MUL64_RES      : in std_logic_vector(63 downto 0);

    TRIG_ENABLE    : out std_logic;
    TRIG_ANGLE     : out std_logic_vector(63 downto 0);
    TRIG_SIN       : in std_logic_vector(63 downto 0);
    TRIG_COS       : in std_logic_vector(63 downto 0);
    TRIG_DONE      : in std_logic;

    GPS_X          : out std_logic_vector(63 downto 0);
    GPS_Y          : out std_logic_vector(63 downto 0);
    GPS_THETA      : out std_logic_vector(63 downto 0);

    BUSY           : out std_logic
    );
end robot_gps_odo;

architecture robot_gps_odo_rtl of robot_gps_odo is

  constant GPS_SAMPLING_T    : std_logic_vector(31 downto 0) :=
    X"000F423F"; -- 40 ms avec pclk=25MHz

  signal iGPS_X              : std_logic_vector(63 downto 0);
  signal iGPS_Y              : std_logic_vector(63 downto 0);
  signal iGPS_THETA          : std_logic_vector(63 downto 0);

  signal iQUAD_CNT_TH_R      : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_R_R       : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_TH_L      : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_R_L       : std_logic_vector(63 downto 0);

  signal iQUAD_CNT_TH_R_OLD  : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_R_R_OLD   : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_TH_L_OLD  : std_logic_vector(63 downto 0);
  signal iQUAD_CNT_R_L_OLD   : std_logic_vector(63 downto 0);

  signal iQUAD_DELTA_TH_R    : std_logic_vector(63 downto 0);
  signal iQUAD_DELTA_R_R     : std_logic_vector(63 downto 0);
  signal iQUAD_DELTA_TH_L    : std_logic_vector(63 downto 0);
  signal iQUAD_DELTA_R_L     : std_logic_vector(63 downto 0);

  signal iGPS_TICKS          : std_logic_vector(31 downto 0);

  type fsm_states is (
    fsm_idle ,
    fsm_setup ,
    fsm_idle_enabled ,
    fsm_read_odo ,
    fsm_compute_delta ,
    fsm_compute_theta ,
    fsm_compute_trigo ,
    fsm_compute_x ,
    fsm_compute_y ,
    fsm_done
    );

  signal fsm_state           : fsm_states;


begin --architecture robot_gps_odo_rtl		 

  gps_proc : process (clock_i, resetb_i)
  begin
    if resetb_i = '0' then
      iGPS_X              <= X"0000000000000000";  -- 0.0 mm
      iGPS_Y              <= X"0064000000000000";  -- 100.0 mm
      iGPS_THETA          <= X"0001921fb54442d1";  -- PI/2 radians
      iQUAD_CNT_TH_R      <= (others => '0');
      iQUAD_CNT_R_R       <= (others => '0');
      iQUAD_CNT_TH_L      <= (others => '0');
      iQUAD_CNT_R_L       <= (others => '0');
      iQUAD_CNT_TH_R_OLD  <= (others => '0');
      iQUAD_CNT_R_R_OLD   <= (others => '0');
      iQUAD_CNT_TH_L_OLD  <= (others => '0');
      iQUAD_CNT_R_L_OLD   <= (others => '0');
      iQUAD_DELTA_TH_R    <= (others => '0');
      iQUAD_DELTA_R_R     <= (others => '0');
      iQUAD_DELTA_TH_L    <= (others => '0');
      iQUAD_DELTA_R_L     <= (others => '0');
      MUL64_OP1           <= (others => '0');
      MUL64_OP2           <= (others => '0');
      TRIG_ENABLE         <= '0';
      TRIG_ANGLE          <= (others => '0');
      iGPS_TICKS          <= (others => '0');
    elsif rising_edge(clock_i) then
      case fsm_state is
        when fsm_idle =>
          if SETUP = '1' then
            fsm_state <= fsm_setup;
          elsif ENABLE = '1' then
            fsm_state <= fsm_idle_enabled;
          end if;
        when fsm_setup =>
          iGPS_X              <= GPS_X_INIT;
          iGPS_Y              <= GPS_Y_INIT;
          iGPS_THETA          <= GPS_THETA_INIT;
          iQUAD_CNT_TH_R      <= QUAD_CNT_TH_R;
          iQUAD_CNT_R_R       <= QUAD_CNT_R_R;
          iQUAD_CNT_TH_L      <= QUAD_CNT_TH_L;
          iQUAD_CNT_R_L       <= QUAD_CNT_R_L;
          iQUAD_CNT_TH_R_OLD  <= QUAD_CNT_TH_R;
          iQUAD_CNT_R_R_OLD   <= QUAD_CNT_R_R;
          iQUAD_CNT_TH_L_OLD  <= QUAD_CNT_TH_L;
          iQUAD_CNT_R_L_OLD   <= QUAD_CNT_R_L;
          iQUAD_DELTA_TH_R    <= (others => '0');
          iQUAD_DELTA_R_R     <= (others => '0');
          iQUAD_DELTA_TH_L    <= (others => '0');
          iQUAD_DELTA_R_L     <= (others => '0');
          if SETUP = '0' then
            fsm_state <= fsm_idle;
          end if;
        when fsm_idle_enabled =>
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          elsif iGPS_TICKS = X"00000000" then
            fsm_state <= fsm_read_odo;
          end if;
        when fsm_read_odo =>                                  -- gps_ticks = 1
          iQUAD_CNT_TH_R      <= QUAD_CNT_TH_R;
          iQUAD_CNT_R_R       <= QUAD_CNT_R_R;
          iQUAD_CNT_TH_L      <= QUAD_CNT_TH_L;
          iQUAD_CNT_R_L       <= QUAD_CNT_R_L;
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            fsm_state <= fsm_compute_delta;
          end if;
        when fsm_compute_delta =>                             -- gps_ticks = 2
          iQUAD_DELTA_TH_R    <= iQUAD_CNT_TH_R - iQUAD_CNT_TH_R_OLD;
          iQUAD_DELTA_R_R     <= iQUAD_CNT_R_R  - iQUAD_CNT_R_R_OLD;
          iQUAD_DELTA_TH_L    <= iQUAD_CNT_TH_L - iQUAD_CNT_TH_L_OLD;
          iQUAD_DELTA_R_L     <= iQUAD_CNT_R_L  - iQUAD_CNT_R_L_OLD;
          iQUAD_CNT_TH_R_OLD  <= iQUAD_CNT_TH_R;
          iQUAD_CNT_R_R_OLD   <= iQUAD_CNT_R_R;
          iQUAD_CNT_TH_L_OLD  <= iQUAD_CNT_TH_L;
          iQUAD_CNT_R_L_OLD   <= iQUAD_CNT_R_L;
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            fsm_state <= fsm_compute_theta;
          end if;
        when fsm_compute_theta =>                             -- gps_ticks = 3
          if (iQUAD_DELTA_R_R(63) = '0') then
            iQUAD_DELTA_R_R <= '0' & iQUAD_DELTA_R_R(63 downto 1);
          else
            iQUAD_DELTA_R_R <= '1' & iQUAD_DELTA_R_R(63 downto 1);
          end if;
          if (iQUAD_DELTA_R_L(63) = '0') then
            iQUAD_DELTA_R_L <= '0' & iQUAD_DELTA_R_L(63 downto 1);
          else
            iQUAD_DELTA_R_L <= '1' & iQUAD_DELTA_R_L(63 downto 1);
          end if;
          iGPS_THETA  <= iGPS_THETA + (iQUAD_DELTA_TH_R - iQUAD_DELTA_TH_L);
          TRIG_ANGLE  <= iGPS_THETA + (iQUAD_DELTA_TH_R - iQUAD_DELTA_TH_L);
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            TRIG_ENABLE <= '1';
            fsm_state <= fsm_compute_trigo;
          end if;
        when fsm_compute_trigo =>                             -- gps_ticks = 4
          TRIG_ENABLE <= '0';
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          elsif TRIG_DONE = '1' then
            MUL64_OP1 <= TRIG_COS;
            MUL64_OP2 <= iQUAD_DELTA_R_R + iQUAD_DELTA_R_L;
            fsm_state <= fsm_compute_x;
          end if;
        when fsm_compute_x =>                                 -- gps_ticks ~ 40
          iGPS_X      <= iGPS_X + MUL64_RES;
          MUL64_OP1 <= TRIG_SIN;
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            fsm_state <= fsm_compute_y;
          end if;
        when fsm_compute_y =>                                 -- gps_ticks ~ 41
          iGPS_Y      <= iGPS_Y + MUL64_RES;
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            fsm_state <= fsm_done;
          end if;
        when fsm_done =>                                      -- gps_ticks ~ 42
          if ENABLE = '0' then
            fsm_state <= fsm_idle;
          else
            fsm_state <= fsm_idle_enabled;
          end if;
        when others => fsm_state <= fsm_idle;
      end case;  
      if iGPS_TICKS = GPS_SAMPLING_T then
        iGPS_TICKS <= X"00000000";
      else
        iGPS_TICKS <= iGPS_TICKS + 1;
      end if;
    end if;
  end process;

  GPS_X          <= iGPS_X;
  GPS_Y          <= iGPS_Y;
  GPS_THETA      <= iGPS_THETA;

  BUSY <= '0' when
          (fsm_state=fsm_idle) or
          (fsm_state=fsm_setup) or 
          (fsm_state=fsm_idle_enabled)
          else '1';

end robot_gps_odo_rtl;
