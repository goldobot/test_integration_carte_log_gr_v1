--
-- Motorola MC68HC11E based SPI interface
--
-- Currently only MASTER mode is supported
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_misc.all;
use work.target.all;
use work.config.all;
use work.iface.all;
use work.macro.all;
use work.amba.all;


entity spi_apb is
  port (
    clk_i		: in std_logic         -- clock
    ; rst_i		: in std_logic         -- reset (asynchronous active low)
    ; apbi   	: in  apb_slv_in_type
    ; apbo   	: out apb_slv_out_type
    ; inta_o	: out std_logic         -- interrupt output

    -- SPI port
    ; sck_o		: out std_logic         -- serial clock output
    ; mosi_o	: out std_logic        -- MasterOut SlaveIN
    ; miso_i	: in std_logic        -- MasterIn SlaveOut
    );
end;

architecture rtl of spi_apb is

  signal tcnt	: unsigned(1 downto 0); -- transfer count
  signal clkcnt	: unsigned(11 downto 0);
  signal ena 	: std_logic;

  signal spr 	: std_logic_vector(1 downto 0); -- Clock Rate Select Bits
  signal icnt 	: unsigned(1 downto 0); -- interrupt on transfer count
  signal spol 	: std_logic; -- switch polarity between read and write mode spol='0' => spi complaiance
  signal spre 	: std_logic_vector(1 downto 0);	-- extended clock rate select
  signal espr 	: std_logic_vector(3 downto 0);

  signal wr_spsr	: std_logic; -- decode Serial Peripheral Extension Register

  signal cpha	: std_logic;   -- Clock Phase Bit
  signal cpol	: std_logic;   -- Clock Polarity Bit
  signal mstr	: std_logic;   -- Master Mode Select Bit
  signal dwom	: std_logic;   -- Port D Wired-OR Mode Bit
  signal spe	: std_logic;   -- System Enable bit
  signal spen	: std_logic;   -- NOT System Enable bit
  signal spie	: std_logic;   -- Interrupt enable bit
  signal spif	: std_logic;
  signal wcol	: std_logic;
  --
  -- Module body
  --
  signal spcr	: std_logic_vector(7 downto 0); -- Serial Peripheral Control Register ('HC11 naming)
  signal spsr	: std_logic_vector(7 downto 0); -- Serial Peripheral Status register ('HC11 naming)
  signal sper	: std_logic_vector(7 downto 0); -- Serial Peripheral Extension register
  signal treg	: std_logic_vector(7 downto 0); -- Transmit register
  signal rreg	: std_logic_vector(7 downto 0); -- Receive register

  -- fifo signals
  signal rfdout	: std_logic_vector(7 downto 0);
  signal wfre, rfwe	: std_logic;
  signal rfre, rffull, rfempty	: std_logic;
  signal wfdout	: std_logic_vector(7 downto 0);
  signal wfwe, wffull, wfempty	: std_logic;

  -- misc signals
  signal tirq	: std_logic;     -- transfer interrupt (selected number of transfers done)
  signal wfov	: std_logic;     -- write fifo overrun (writing while fifo full)
  signal state	: std_logic_vector(1 downto 0); -- statemachine state
  signal bcnt	: unsigned(2 downto 0);

  signal wb_acc	: std_logic;
  signal wb_wr	: std_logic;

  signal ack	: std_logic;
  signal sck	: std_logic;         -- serial clock output

  component spi_fifo
    generic (
      DATAWIDTH : natural := 8
      );
    port (
      clk   : in std_logic
      ; rst   : in std_logic
      ; clr   : in std_logic
      ; din   : in std_logic_vector(DATAWIDTH-1 downto 0)
      ; we    : in std_logic
      ; dout  : out std_logic_vector(DATAWIDTH-1 downto 0)
      ; re    : in std_logic
      ; full  : out std_logic
      ; empty : out std_logic
      );
  end component;

  signal cyc_i	: std_logic;         		-- cycle
  signal stb_i	: std_logic;         		-- strobe
  signal adr_i	: std_logic_vector(1 downto 0);	-- address
  signal we_i	: std_logic;         		-- write enable
  signal dat_i	: std_logic_vector(7 downto 0);	-- data input
  signal dat_o	: std_logic_vector(7 downto 0);	-- data output
  signal ack_o	: std_logic;		        -- normal bus termination

begin

  -- APB to Wishbone
  cyc_i <= apbi.psel;
  stb_i <= apbi.psel;
  we_i  <= apbi.pwrite;
  adr_i <= apbi.paddr(3 downto 2);
  dat_i <= apbi.pwdata(7 downto 0);
  apbo.prdata <= dat_o & dat_o & dat_o & dat_o;

  ack_o <= ack;
  sck_o <= sck;

  --
  -- Wishbone interface
  wb_acc <= cyc_i and stb_i;       -- WISHBONE access
  wb_wr  <= wb_acc and we_i;       -- WISHBONE write access

  -- dat_i
  process(clk_i,rst_i)
  begin
    if rst_i = '0' then
      spcr	<= X"10"; -- set master bit
      sper	<= X"00";
    elsif rising_edge(clk_i) then
      if wb_wr = '1' then
        if adr_i = "00" then
          spcr <= dat_i or X"10"; -- always set master bit
        end if;

        if adr_i = "11" then
          sper <= dat_i;
        end if;
      end if;
    end if;
  end process;

  -- write fifo
  wfwe <= '1' when (wb_acc = '1') and (adr_i = "10") and (ack = '1') and (we_i = '1') else '0';
  wfov <= wfwe and wffull;

  -- dat_o
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      case adr_i is
        when "00" =>
          dat_o	<= spcr;
        when "01" =>
          dat_o	<= spsr;
        when "10" =>
          dat_o	<= rfdout;
        when "11" =>
          dat_o	<= sper;
        when others =>
      end case;
    end if;
  end process;
  
  -- read fifo
  rfre <= '1' when (wb_acc = '1') and (adr_i = "10") and (ack = '1') and (we_i = '0') else '0';

  -- ack
  process(clk_i,rst_i)
  begin
    if rst_i = '0' then
      ack <= '0';
    elsif rising_edge(clk_i) then
      ack <= wb_acc and not(ack);
    end if;
  end process;
  -- decode Serial Peripheral Control Register
  spie <= spcr(7);   -- Interrupt enable bit
  spe  <= spcr(6);   -- System Enable bit
  spen  <= not(spcr(6));   -- NOT System Enable bit
  dwom <= spcr(5);   -- Port D Wired-OR Mode Bit
  mstr <= spcr(4);   -- Master Mode Select Bit
  cpol <= spcr(3);   -- Clock Polarity Bit
  cpha <= spcr(2);   -- Clock Phase Bit
  spr  <= spcr(1 downto 0); -- Clock Rate Select Bits

  -- decode Serial Peripheral Extension Register
  icnt <= unsigned(sper(7 downto 6)); -- interrupt on transfer count
  spol <= sper(2); -- switch polarity between read and write mode
  spre <= sper(1 downto 0); -- extended clock rate select

  espr <= spre & spr;

  -- generate status register
  wr_spsr <= '1' when (wb_wr = '1') and (adr_i = "01") else '0';

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if spe = '0' then
        spif <= '0';
      else
        spif <= (tirq or spif) and not(wr_spsr and dat_i(7));
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if spe = '0' then
        wcol <= '0';
      else
        wcol <= (wfov or wcol) and not(wr_spsr and dat_i(6));
      end if;
    end if;
  end process;

  spsr(7)   <= spif;
  spsr(6)   <= wcol;
  spsr(5 downto 4) <= "00";
  spsr(3)   <= wffull;
  spsr(2)   <= wfempty;
  spsr(1)   <= rffull;
  spsr(0)   <= rfempty;


  -- generate IRQ output (inta_o)
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      inta_o <= spif and spie;
    end if;
  end process;

  --
  -- hookup read/write buffer fifo
  rfifo : spi_fifo
    generic map (
      DATAWIDTH	=> 8
      )
    port map (
      clk   => clk_i
      , rst   => rst_i
      , clr   => spen
--		, din   => treg
      , din   => rreg
      , we    => rfwe
      , dout  => rfdout
      , re    => rfre
      , full  => rffull
      , empty => rfempty
      );
  wrifo : spi_fifo
    generic map (
      DATAWIDTH	=> 8
      )
    port map (
      clk   => clk_i
      , rst   => rst_i
      , clr   => spen
      , din   => dat_i
      , we    => wfwe
      , dout  => wfdout
      , re    => wfre
      , full  => wffull
      , empty => wfempty
      );

  --
  -- generate clk divider
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (spe = '1') and ((or_reduce(std_logic_vector(clkcnt)) = '1')  and (or_reduce(state) = '1')) then
        clkcnt <= clkcnt - "00000000001";
      else
        case espr is
          when "0000" =>
            clkcnt <= X"000";   -- 2   -- original M68HC11 coding
          when "0001" =>
            clkcnt <= X"001";   -- 4   -- original M68HC11 coding
          when "0010" =>
            clkcnt <= X"003";   -- 16  -- original M68HC11 coding
          when "0011" =>
            clkcnt <= X"00f";   -- 32  -- original M68HC11 coding
          when "0100" =>
            clkcnt <= X"01f";  -- 8
          when "0101" =>
            clkcnt <= X"007";   -- 64
          when "0110" =>
            clkcnt <= X"03f";  -- 128
          when "0111" =>
            clkcnt <= X"07f";  -- 256
          when "1000" =>
            clkcnt <= X"0ff";  -- 512
          when "1001" =>
            clkcnt <= X"1ff"; -- 1024
          when "1010" =>
            clkcnt <= X"3ff"; -- 2048
          when "1011" =>
            clkcnt <= X"7ff"; -- 4096
          when others =>
        end case;
      end if;

    end if;
  end process;

  -- generate clock enable signal
  ena <= not(or_reduce(std_logic_vector(clkcnt)));

  -- transfer statemachine
  process(clk_i,rst_i)
  begin
    if rst_i = '0' then
      state <= "00"; -- idle
      bcnt  <= "000";
      treg  <= X"00";
      rreg  <= X"00";
      wfre  <= '0';
      rfwe  <= '0';
      sck <= '0';
    elsif rising_edge(clk_i) then
      if spe = '0' then
        state <= "00"; -- idle
        bcnt  <= "000";
        treg  <= X"00";
        rreg  <= X"00";
        wfre  <= '0';
        rfwe  <= '0';
        sck <= '0';
      else
        wfre <= '0';
        rfwe <= '0';

        if spol = '1' then
          case state is --synopsys full_case parallel_case
            when "00" => -- idle state
              bcnt  <= "111";   -- set transfer counter
              treg  <= wfdout; -- load transfer register
              rreg  <= (others => '0'); -- reset read transfer register
              sck <= cpol;   -- set sck

              if (wfempty = '0') then
                wfre  <= '1';
                state <= "01";
                if (cpha = '1') then
                  sck <= not(sck);
                end if;
              end if;

            when "01" => -- clock-phase2, next data
              if (ena = '1') then
                sck   <= not(sck);
                state <= "11";
              end if;

            when "11" => -- clock phase1
              if (ena = '1') then
                treg <= treg(6 downto 0) & '0';
                rreg <= rreg(6 downto 0) & miso_i;
                bcnt <= bcnt - "1";

                if not(or_reduce(std_logic_vector(bcnt))) = '1' then
                  state <= "00";
                  sck <= cpol;
                  rfwe <= '1';
                else
                  state <= "01";
                  sck <= not(sck);
                end if;
              end if;

            when "10" =>
            when others =>
          end case;
        else
          case state is --synopsys full_case parallel_case
            when "00" => -- idle state
              bcnt  <= "111";   -- set transfer counter
              treg  <= wfdout; -- load transfer register
              rreg  <= (others => '0'); -- reset read transfer register
              sck <= cpol;   -- set sck

              if (wfempty = '0') then
                wfre  <= '1';
                state <= "01";
                if (cpha = '1') then
                  sck <= not(sck);
                end if;
              end if;

            when "01" => -- clock-phase2, next data
              if (ena = '1') then
                sck   <= not(sck);
                state <= "11";

                rreg <= rreg(6 downto 0) & miso_i;
                if not(or_reduce(std_logic_vector(bcnt))) = '1' then
                  rfwe <= '1';
                end if;

              end if;

            when "11" => -- clock phase1
              if (ena = '1') then
                treg <= treg(6 downto 0) & '0';
                bcnt <= bcnt - "1";

                if not(or_reduce(std_logic_vector(bcnt))) = '1' then
                  state <= "00";
                  sck <= cpol;
                else
                  state <= "01";
                  sck <= not(sck);
                end if;
              end if;

            when "10" =>
            when others =>
          end case;
        end if;
      end if;
    end if;
  end process;

  mosi_o <= treg(7)
--pragma translate_off
            after 2 ns
--pragma translate_on
            ;


  -- count number of transfers (for interrupt generation)
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (spe = '0') then
        tcnt <= icnt;
      elsif (rfwe = '1') then -- rfwe gets asserted when all bits have been transfered
        if or_reduce(std_logic_vector(tcnt)) = '1' then
          tcnt <= tcnt - "1";
        else
          tcnt <= icnt;
        end if;
      end if;
    end if;
  end process;

  tirq <= not(or_reduce(std_logic_vector(tcnt))) and rfwe;

end rtl;
