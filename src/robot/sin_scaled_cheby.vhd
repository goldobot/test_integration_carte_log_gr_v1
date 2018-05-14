-- operation realisee : f(x) = sin (x)
-- DATAIN et DATAOUT sont en virgule fixe (signee) Q15.48

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

entity sin_scaled_cheby is
  port (
    clock_i  : in std_logic;
    resetb_i : in std_logic;
    COMMAND  : in std_logic_vector(31 downto 0);
    STATUS   : out std_logic_vector(31 downto 0);
    DATAIN   : in std_logic_vector(63 downto 0);
    DATAOUT  : out std_logic_vector(63 downto 0)
    );
end sin_scaled_cheby;

architecture sin_scaled_cheby_arch of sin_scaled_cheby is

  component mul_int64
    port (
      dataa               : in std_logic_vector (63 downto 0);
      datab               : in std_logic_vector (63 downto 0);
      result              : out std_logic_vector (127 downto 0)
      );
  end component;

  constant M_PI_SCALED          : std_logic_vector (49 downto 0) :=
    "10000000000000000000000000000000000000000000000000";
  constant M_2PI_SCALED         : std_logic_vector (49 downto 0) :=
    "00000000000000000000000000000000000000000000000000";

  signal start_s                : std_logic;

  signal done_o                 : std_logic;
  signal done_o_old             : std_logic;

  signal iMUL64_DATAA           : std_logic_vector (63 downto 0);
  signal iMUL64_DATAB           : std_logic_vector (63 downto 0);
  signal iMUL64_RESULT          : std_logic_vector (127 downto 0);


  type sin_fsm_states is (
    sin_fsm_idle ,
    sin_fsm_init_scale ,
    sin_fsm_init_normalize ,
    sin_fsm_iterate_clenshaw ,
    sin_fsm_last_clenshaw ,
    sin_fsm_done
    );

  signal sin_fsm_state          : sin_fsm_states;

  signal sin_clenshaw_iterator  : integer;

  signal in_angle               : std_logic_vector (63 downto 0);

  signal var_x_ll               : std_logic_vector (63 downto 0);
  signal var_ret_ll             : std_logic_vector (63 downto 0);
  signal var_b_r1               : std_logic_vector (63 downto 0);
  signal var_b_r2               : std_logic_vector (63 downto 0);
  signal x_ll_X_b_r1            : std_logic_vector (63 downto 0);

  signal cheby_coeff            : std_logic_vector (63 downto 0);

  signal neg_out                : std_logic;

begin

  start_s <= COMMAND(0);


  c_mul64 : mul_int64
    port map (
      dataa  => iMUL64_DATAA,
      datab  => iMUL64_DATAB,
      result => iMUL64_RESULT
    );

  cheby_coeff_proc : process (sin_clenshaw_iterator)
  begin
    case sin_clenshaw_iterator is
      when  0 => cheby_coeff <= X"0000000000000000";
      when  1 => cheby_coeff <= X"00012236c458df17";
      when  2 => cheby_coeff <= X"0000000000000000";
      when  3 => cheby_coeff <= X"ffffdca753fb0eb2";
      when  4 => cheby_coeff <= X"0000000000000000";
      when  5 => cheby_coeff <= X"000001264daed31b";
      when  6 => cheby_coeff <= X"0000000000000000";
      when  7 => cheby_coeff <= X"fffffffb90293c00";
      when  8 => cheby_coeff <= X"0000000000000000";
      when  9 => cheby_coeff <= X"0000000009e24ac5";
      when 10 => cheby_coeff <= X"0000000000000000";
      when 11 => cheby_coeff <= X"fffffffffff1a9c4";
      when 12 => cheby_coeff <= X"0000000000000000";
      when 13 => cheby_coeff <= X"0000000000000e9e";
      when 14 => cheby_coeff <= X"0000000000000000";
      when others => cheby_coeff <= X"0000000000000000";
    end case;  
  end process;

  iMUL64_DATAA <= DATAIN              when (sin_fsm_state=sin_fsm_init_scale)
                  else var_x_ll;
  iMUL64_DATAB <= X"0000a2f9836e4e44" when (sin_fsm_state=sin_fsm_init_scale)
                  else var_b_r1;
  x_ll_X_b_r1 <= iMUL64_RESULT (111 downto 48);

  clenshaw_proc : process (clock_i, resetb_i)
  begin
    if resetb_i = '0' then
      sin_fsm_state <= sin_fsm_idle;
      done_o        <= '0';
      var_x_ll      <= (others => '0');
      var_ret_ll    <= (others => '0');
      var_b_r1      <= (others => '0');
      var_b_r2      <= (others => '0');
      sin_clenshaw_iterator <= 14;
      in_angle      <= (others => '0');
      neg_out       <= '0';
    elsif rising_edge(clock_i) then
      case sin_fsm_state is
        when sin_fsm_idle =>
          done_o <= '0';
          if start_s = '1' then
            sin_fsm_state <= sin_fsm_init_scale;
          end if;
        when sin_fsm_init_scale =>
          -- division par PI/2
--          var_x_ll <= DATAIN;
          in_angle <= iMUL64_RESULT (111 downto 48);
          sin_fsm_state <= sin_fsm_init_normalize;
        when sin_fsm_init_normalize =>
          -- detection du quadrant et reduction a l'intervale [0, PI/2]
          case in_angle(49 downto 48) is
            when "00" =>
              var_x_ll <= "00000000000000" &
                          in_angle(49 downto 0);
              neg_out  <= '0';
            when "01" =>
              var_x_ll <= "00000000000000" &
                          (M_PI_SCALED - in_angle(49 downto 0));
              neg_out  <= '0';
            when "10" =>
              var_x_ll <= "00000000000000" &
                          (in_angle(49 downto 0) - M_PI_SCALED);
              neg_out  <= '1';
            when "11" =>
              var_x_ll <= "00000000000000" &
                          (M_2PI_SCALED - in_angle(49 downto 0));
              neg_out  <= '1';
          end case;  
          var_b_r1 <= (others => '0');
          var_b_r2 <= (others => '0');
          sin_clenshaw_iterator <= 14;
          sin_fsm_state <= sin_fsm_iterate_clenshaw;
        when sin_fsm_iterate_clenshaw =>
          if sin_clenshaw_iterator = 0 then
            sin_fsm_state <= sin_fsm_last_clenshaw;
          else
            var_b_r1 <= cheby_coeff + x_ll_X_b_r1 + x_ll_X_b_r1 - var_b_r2;
            var_b_r2 <= var_b_r1;
            sin_clenshaw_iterator <= sin_clenshaw_iterator - 1;
          end if;
        when sin_fsm_last_clenshaw =>
          var_ret_ll <= x_ll_X_b_r1 - var_b_r2 + cheby_coeff;
          sin_fsm_state <= sin_fsm_done;
        when sin_fsm_done =>
          if neg_out = '1' then
            var_ret_ll <= X"0000000000000000" - var_ret_ll;
          end if;
          done_o <= '1';
          sin_fsm_state <= sin_fsm_idle;
        when others => sin_fsm_state <= sin_fsm_idle;
      end case;  
    end if;
  end process;


  status_proc : process (clock_i, resetb_i)
  begin
    if resetb_i = '0' then
      STATUS <= (others => '0');
      done_o_old <= '0';
      DATAOUT <= (others => '1');
    elsif rising_edge(clock_i) then
      if(start_s = '1') then
        STATUS(0) <= '0';
      end if;
      if((done_o_old = '0') and (done_o = '1')) then
        DATAOUT <= var_ret_ll;
        STATUS(0) <= '1';
      end if;
      done_o_old <= done_o;
    end if;
  end process;
  
end sin_scaled_cheby_arch;

