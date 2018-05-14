-- operation realisee : f(x) = sin (x)
-- DATAIN et DATAOUT sont en virgule fixe (signee) Q15.48

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned."+";
use IEEE.std_logic_unsigned."-";
use IEEE.std_logic_unsigned.conv_integer;
use IEEE.numeric_std.all;

entity sin_cos_cheby is
  port (
    clock_i      : in std_logic;
    resetb_i     : in std_logic;
    COMMAND      : in std_logic_vector(31 downto 0);
    STATUS       : out std_logic_vector(31 downto 0);
    DATAIN       : in std_logic_vector(63 downto 0);
    DATAOUT_SIN  : out std_logic_vector(63 downto 0);
    DATAOUT_COS  : out std_logic_vector(63 downto 0)
    );
end sin_cos_cheby;

architecture sin_cos_cheby_arch of sin_cos_cheby is

  component mul_int64
    port (
      dataa               : in std_logic_vector (63 downto 0);
      datab               : in std_logic_vector (63 downto 0);
      result              : out std_logic_vector (127 downto 0)
      );
  end component;

  constant M_PI2_SCALED         : std_logic_vector (49 downto 0) :=
    "01000000000000000000000000000000000000000000000000";
  constant M_PI_SCALED          : std_logic_vector (49 downto 0) :=
    "10000000000000000000000000000000000000000000000000";
  constant M_3PI2_SCALED        : std_logic_vector (49 downto 0) :=
    "11000000000000000000000000000000000000000000000000";
  constant M_2PI_SCALED         : std_logic_vector (49 downto 0) :=
    "00000000000000000000000000000000000000000000000000";

  signal start_s                : std_logic;

  signal done_o                 : std_logic;
  signal done_o_old             : std_logic;

  signal iMUL64_DATAA           : std_logic_vector (63 downto 0);
  signal iMUL64_DATAB           : std_logic_vector (63 downto 0);
  signal iMUL64_RESULT          : std_logic_vector (127 downto 0);


  type fsm_states is (
    fsm_idle ,
    fsm_init_scale ,
    fsm_init_normalize ,
    fsm_iterate_clenshaw_sin ,
    fsm_last_clenshaw_sin ,
    fsm_done_sin,
    fsm_iterate_clenshaw_cos ,
    fsm_last_clenshaw_cos ,
    fsm_done_cos,
    fsm_done
    );

  signal fsm_state              : fsm_states;

  signal clenshaw_iterator      : integer;

  signal in_angle               : std_logic_vector (63 downto 0);

  signal var_x_ll               : std_logic_vector (63 downto 0);
  signal var_x_ll_cos           : std_logic_vector (63 downto 0);
  signal var_ret_ll             : std_logic_vector (63 downto 0);
  signal var_ret_ll_sin         : std_logic_vector (63 downto 0);
  signal var_ret_ll_cos         : std_logic_vector (63 downto 0);
  signal var_b_r1               : std_logic_vector (63 downto 0);
  signal var_b_r2               : std_logic_vector (63 downto 0);
  signal x_ll_X_b_r1            : std_logic_vector (63 downto 0);

  signal cheby_coeff            : std_logic_vector (63 downto 0);

  signal neg_out_sin            : std_logic;
  signal neg_out_cos            : std_logic;

begin

  start_s <= COMMAND(0);


  c_mul64 : mul_int64
    port map (
      dataa  => iMUL64_DATAA,
      datab  => iMUL64_DATAB,
      result => iMUL64_RESULT
    );

  cheby_coeff_proc : process (clenshaw_iterator)
  begin
    case clenshaw_iterator is
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

  iMUL64_DATAA <= DATAIN              when (fsm_state=fsm_init_scale)
                  else var_x_ll;
  iMUL64_DATAB <= X"0000a2f9836e4e44" when (fsm_state=fsm_init_scale)
                  else var_b_r1;
  x_ll_X_b_r1 <= iMUL64_RESULT (111 downto 48);

  clenshaw_proc : process (clock_i, resetb_i)
  begin
    if resetb_i = '0' then
      fsm_state     <= fsm_idle;
      done_o        <= '0';
      var_x_ll      <= (others => '0');
      var_x_ll_cos  <= (others => '0');
      var_ret_ll    <= (others => '0');
      var_ret_ll_sin <= (others => '0');
      var_ret_ll_cos <= (others => '0');
      var_b_r1      <= (others => '0');
      var_b_r2      <= (others => '0');
      clenshaw_iterator <= 14;
      in_angle      <= (others => '0');
      neg_out_sin   <= '0';
      neg_out_cos   <= '0';
    elsif rising_edge(clock_i) then
      case fsm_state is
        when fsm_idle =>
          done_o <= '0';
          if start_s = '1' then
            fsm_state <= fsm_init_scale;
          end if;
        when fsm_init_scale =>
          -- division par PI/2
          in_angle <= iMUL64_RESULT (111 downto 48);
          fsm_state <= fsm_init_normalize;
        when fsm_init_normalize =>
          -- detection du quadrant et reduction a l'intervale [0, PI/2]
          case in_angle(49 downto 48) is
            when "00" =>
              var_x_ll <= "00000000000000" &
                          in_angle(49 downto 0);
              neg_out_sin <= '0';
              var_x_ll_cos <= "00000000000000" &
                          (M_PI2_SCALED - in_angle(49 downto 0));
              neg_out_cos <= '0';
            when "01" =>
              var_x_ll <= "00000000000000" &
                          (M_PI_SCALED - in_angle(49 downto 0));
              neg_out_sin  <= '0';
              var_x_ll_cos <= "00000000000000" &
                          (in_angle(49 downto 0) - M_PI2_SCALED);
              neg_out_cos <= '1';
            when "10" =>
              var_x_ll <= "00000000000000" &
                          (in_angle(49 downto 0) - M_PI_SCALED);
              neg_out_sin  <= '1';
              var_x_ll_cos <= "00000000000000" &
                          (M_3PI2_SCALED - in_angle(49 downto 0));
              neg_out_cos <= '1';
            when "11" =>
              var_x_ll <= "00000000000000" &
                          (M_2PI_SCALED - in_angle(49 downto 0));
              neg_out_sin  <= '1';
              var_x_ll_cos <= "00000000000000" &
                          (in_angle(49 downto 0) - M_3PI2_SCALED);
              neg_out_cos <= '0';
          end case;  
          var_b_r1 <= (others => '0');
          var_b_r2 <= (others => '0');
          clenshaw_iterator <= 14;
          fsm_state <= fsm_iterate_clenshaw_sin;

        when fsm_iterate_clenshaw_sin =>
          if clenshaw_iterator = 0 then
            fsm_state <= fsm_last_clenshaw_sin;
          else
            var_b_r1 <= cheby_coeff + x_ll_X_b_r1 + x_ll_X_b_r1 - var_b_r2;
            var_b_r2 <= var_b_r1;
            clenshaw_iterator <= clenshaw_iterator - 1;
          end if;
        when fsm_last_clenshaw_sin =>
          var_ret_ll <= x_ll_X_b_r1 - var_b_r2 + cheby_coeff;
          fsm_state <= fsm_done_sin;
        when fsm_done_sin =>
          if neg_out_sin = '1' then
            var_ret_ll_sin <= X"0000000000000000" - var_ret_ll;
          else
            var_ret_ll_sin <= var_ret_ll;
          end if;
          var_x_ll <= var_x_ll_cos;
          var_b_r1 <= (others => '0');
          var_b_r2 <= (others => '0');
          clenshaw_iterator <= 14;
          fsm_state <= fsm_iterate_clenshaw_cos;

        when fsm_iterate_clenshaw_cos =>
          if clenshaw_iterator = 0 then
            fsm_state <= fsm_last_clenshaw_cos;
          else
            var_b_r1 <= cheby_coeff + x_ll_X_b_r1 + x_ll_X_b_r1 - var_b_r2;
            var_b_r2 <= var_b_r1;
            clenshaw_iterator <= clenshaw_iterator - 1;
          end if;
        when fsm_last_clenshaw_cos =>
          var_ret_ll <= x_ll_X_b_r1 - var_b_r2 + cheby_coeff;
          fsm_state <= fsm_done_cos;
        when fsm_done_cos =>
          if neg_out_cos = '1' then
            var_ret_ll_cos <= X"0000000000000000" - var_ret_ll;
          else
            var_ret_ll_cos <= var_ret_ll;
          end if;
          fsm_state <= fsm_done;

        when fsm_done =>
          done_o <= '1';
          fsm_state <= fsm_idle;
        when others => fsm_state <= fsm_idle;
      end case;  
    end if;
  end process;


  status_proc : process (clock_i, resetb_i)
  begin
    if resetb_i = '0' then
      STATUS <= (others => '0');
      done_o_old <= '0';
      DATAOUT_SIN <= (others => '1');
      DATAOUT_COS <= (others => '1');
    elsif rising_edge(clock_i) then
      if(start_s = '1') then
        STATUS(0) <= '0';
      end if;
      if((done_o_old = '0') and (done_o = '1')) then
        DATAOUT_SIN <= var_ret_ll_sin;
        DATAOUT_COS <= var_ret_ll_cos;
        STATUS(0) <= '1';
      end if;
      done_o_old <= done_o;
    end if;
  end process;
  
end sin_cos_cheby_arch;

