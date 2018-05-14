----------------------------------------------------------------------------
-- Entity: 	core_ioport
-- File:	core_ioport.vhd
-- Description:	Parallel I/O port. On reset, all port are programmed as
--		inputs and remaning registers are unknown. This means
--		that the interrupt configuration registers must be
--		written before I/O port interrputs are unmasked in the
--		interrupt controller.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.core_pad_pkg.all;
use work.amba.all;
--pragma translate_off
use work.debug.all;
--pragma translate_on

entity core_ioport is
  port (
    rst    : in  std_logic;
    clk    : in  std_logic;
    testmode : in std_logic;
    leds   : in  std_logic_vector(7 downto 0);
    debug  : in  std_logic_vector(6 downto 0);
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    mode   : out io_mode_type;
    pi     : in  std_logic_vector(IO_MAX-1 downto 0);
    pconfig: in  std_logic_vector(31 downto IO_MAX);
    po     : out std_logic_vector(IO_MAX-1 downto 0);
    pdir   : out std_logic_vector(IO_MAX-1 downto 0);
    irqout : out std_logic_vector(3 downto 0)
    );
end;

architecture rtl of core_ioport is

-- generic multiplexer
  function genmux(s,v : std_logic_vector) return std_logic is
    variable res : std_logic_vector(v'length-1 downto 0); --'
    variable i : integer;
  begin
    res := v;
-- pragma translate_off
    i := 0;
    if not is_x(s) then
-- pragma translate_on
      i := to_integer(unsigned(s));
-- pragma translate_off
    else
      res := (others => 'X');
    end if;
-- pragma translate_on
    return(res(i));
  end;


  constant ISELLEN : integer := 5;
  type irq_ctrl_type is record
    isel	 : std_logic_vector(ISELLEN-1 downto 0);
    pol    : std_logic;
    edge   : std_logic;
    enable : std_logic;
  end record;

  type irq_conf_type is array (3 downto 0) of irq_ctrl_type;

  type pioregs is record
    irqout	:  std_logic_vector(3 downto 0);
    irqlat	:  std_logic_vector(3 downto 0);
    pin1      	:  std_logic_vector(31 downto 0);
    pin2		:  std_logic_vector(31 downto 0);
    pdir		:  std_logic_vector(IO_MAX-1 downto 0);
    pout		:  std_logic_vector(IO_MAX-1 downto 0);
    po     	:  std_logic_vector(IO_MAX-1 downto 0);
    iconf 	:  irq_conf_type;
    mode		:  io_mode_type;
    sel		:  io_selection_type;
  end record;

  signal r, rin : pioregs;
begin


  pioop : process(rst, r, apbi, pi, pconfig, leds, debug)
    variable rdata : std_logic_vector(31 downto 0);
    variable v : pioregs;
    variable leds_debug : std_logic_vector(15 downto 0);
  begin

    v := r;

    v.pin1 := pconfig & pi; v.pin2 := r.pin1;

-- read/write registers

-- | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
-- |cen|cio|in |enable |output |
--   |   |   |     +-------+-> 00 : transparent
--   |   |   |     +-------+-> 01 : synchronized
--   |   |   |     +-------+-> 10 : special io
--   |   |   |     +-------+-> 11 : reserved
--   |   |   +--------------->  0 : transparent
--   |   |   +--------------->  1 : sysnchronized
--   |   +------------------->  0 : non-inverted clock
--   |   +------------------->  1 : inverted clock
--   +----------------------->  0 : non-inverted clock
--   +----------------------->  1 : inverted clock

-- default values:
--
--	addr        pad	                     mode
--                  		cen cio in enable output
--	0	pad_gpio(0)	1   1   0  00     00	: 0x60		; trf7960, rdy pwr enable
--	1	pad_gpio(1)	1   1   0  00     00	: 0x60		; SPI slave select
--	2	pad_gpio(2)	1   1   0  00     00	: 0x60		; trf7960, irq in
--	3	pad_gpio(3)	1   1   0  00     00	: 0x60		; RFU (led in debug mode)
--	4	NA		1   1   0  00     00	: 0x60
--	5	NA		1   1   0  00     00	: 0x60
--	6	NA  		1   1   0  00     00	: 0x60
--	7	NA  		1   1   0  00     00	: 0x60
--	8	C1		1   1   1  00     00	: 0x7A -- non metastable
--	9	C2_n_reset	1   1   1  00     00	: 0x7A -- non metastable
--	10	C3_clk		1   1   1  00     00	: 0x7A -- non metastable
--	11	C7  		1   1   1  00     00	: 0x7A -- non metastable
--	12	rx		1   1   0  10     10	: 0x6A
--	13	tx  		1   1   0  10     10	: 0x6A
--	14	drx		1   1   0  10     10	: 0x6A
--	15	dtx  		1   1   0  10     10	: 0x6A
--	16	sda0  		1   1   0  10     10	: 0x6A
--	17	scl0  		1   1   0  10     10	: 0x6A
--	18	sck  		1   1   0  00     00	: 0x60
--	19	mosi  		1   1   0  00     00	: 0x60
--	20	miso		1   1   0  00     00	: 0x60

-- pout selection
------------------
-- sel	| pout
------------------
-- 0	| pout
-- 1	| debug(0)
-- 2	| debug(1)
-- 3	| debug(2)
-- 4	| debug(3)
-- 5	| debug(4)
-- 6	| debug(5)
-- 7	| debug(6)
-- 8	| leds(0)
-- 9	| leds(1)
-- 10	| leds(2)
-- 11	| leds(3)
-- 12	| leds(4)
-- 13	| leds(5)
-- 14	| leds(6)
-- 15	| leds(7)

    rdata := (others => '0');
    -- WARNING: address decoder behave as if we use not(paddr(7))
    -- see address decoder in apbmst.vhd
    if (apbi.psel and apbi.penable and not(apbi.pwrite)) = '1' then
      case apbi.paddr(7 downto 2) is
        when "100000" => rdata(31 downto 0) := r.pin2;
        when "100001" => rdata(IO_MAX-1 downto 0) := not r.pdir;
        when "100010" => rdata(31 downto 0) :=
                           r.iconf(3).enable & r.iconf(3).edge & r.iconf(3).pol & r.iconf(3).isel &
                           r.iconf(2).enable & r.iconf(2).edge & r.iconf(2).pol & r.iconf(2).isel &
                           r.iconf(1).enable & r.iconf(1).edge & r.iconf(1).pol & r.iconf(1).isel &
                           r.iconf(0).enable & r.iconf(0).edge & r.iconf(0).pol & r.iconf(0).isel;
        when "100011" =>
          -- pout/leds/debug selector
          rdata(3 downto 0) := v.sel(0);
          rdata(7 downto 4) := v.sel(1);
          rdata(11 downto 8) := v.sel(2);
          rdata(15 downto 12) := v.sel(3);
          rdata(19 downto 16) := v.sel(4);
          rdata(23 downto 20) := v.sel(5);
          rdata(27 downto 24) := v.sel(6);
          rdata(31 downto 28) := v.sel(7);
        when "100100" =>
          -- pout/leds/debug selector
          rdata(3 downto 0) := v.sel(8);
          rdata(7 downto 4) := v.sel(9);
          rdata(11 downto 8) := v.sel(10);
          rdata(15 downto 12) := v.sel(11);
          rdata(19 downto 16) := v.sel(12);
          rdata(23 downto 20) := v.sel(13);
          rdata(27 downto 24) := v.sel(14);
          rdata(31 downto 28) := v.sel(15);
        when "100101" =>
          -- pout/leds/debug selector
          rdata(3 downto 0) := v.sel(16);
          rdata(7 downto 4) := v.sel(17);
          rdata(11 downto 8) := v.sel(18);
          rdata(15 downto 12) := v.sel(19);
          rdata(19 downto 16) := v.sel(20);
        when "000000" =>	-- 0
          rdata(6 downto 0) := r.mode(0);
        when "000001" =>	-- 1
          rdata(6 downto 0) := r.mode(1);
        when "000010" =>	-- 2
          rdata(6 downto 0) := r.mode(2);
        when "000011" =>	-- 3
          rdata(6 downto 0) := r.mode(3);
        when "000100" =>	-- 4
          rdata(6 downto 0) := r.mode(4);
        when "000101" =>	-- 5
          rdata(6 downto 0) := r.mode(5);
        when "000110" =>	-- 6
          rdata(6 downto 0) := r.mode(6);
        when "000111" =>	-- 7
          rdata(6 downto 0) := r.mode(7);
        when "001000" =>	-- 8
          rdata(6 downto 0) := r.mode(8);
        when "001001" =>	-- 9
          rdata(6 downto 0) := r.mode(9);
        when "001010" =>	-- 10
          rdata(6 downto 0) := r.mode(10);
        when "001011" =>	-- 11
          rdata(6 downto 0) := r.mode(11);
        when "001100" =>	-- 12
          rdata(6 downto 0) := r.mode(12);
        when "001101" =>	-- 13
          rdata(6 downto 0) := r.mode(13);
        when "001110" =>	-- 14
          rdata(6 downto 0) := r.mode(14);
        when "001111" =>	-- 15
          rdata(6 downto 0) := r.mode(15);
        when "010000" =>	-- 16
          rdata(6 downto 0) := r.mode(16);
        when "010001" =>	-- 17
          rdata(6 downto 0) := r.mode(17);
        when "010010" =>	-- 18
          rdata(6 downto 0) := r.mode(18);
        when "010011" =>	-- 19
          rdata(6 downto 0) := r.mode(19);
        when "010100" =>	-- 20
          rdata(6 downto 0) := r.mode(20);
        when others => rdata := (others => '-');
      end case;
    end if;

    if (apbi.psel and apbi.penable and apbi.pwrite) = '1' then
      -- WARNING: address decoder behave as if we use not(paddr(7))
      -- see address decoder in apbmst.vhd
      case apbi.paddr(7 downto 2) is
        when "100000" =>  v.pout := apbi.pwdata(IO_MAX-1 downto 0);
        when "100001" =>  v.pdir := not apbi.pwdata(IO_MAX-1 downto 0);
        when "100010" =>
          v.iconf(3).enable := apbi.pwdata(31); v.iconf(3).edge := apbi.pwdata(30);
          v.iconf(3).pol := apbi.pwdata(29); v.iconf(3).isel := apbi.pwdata(28 downto 24);
          v.iconf(2).enable := apbi.pwdata(23); v.iconf(2).edge := apbi.pwdata(22);
          v.iconf(2).pol := apbi.pwdata(21); v.iconf(2).isel := apbi.pwdata(20 downto 16);
          v.iconf(1).enable := apbi.pwdata(15); v.iconf(1).edge := apbi.pwdata(14);
          v.iconf(1).pol := apbi.pwdata(13); v.iconf(1).isel := apbi.pwdata(12 downto 8);
          v.iconf(0).enable := apbi.pwdata(7); v.iconf(0).edge := apbi.pwdata(6);
          v.iconf(0).pol := apbi.pwdata(5); v.iconf(0).isel := apbi.pwdata(4 downto 0);
        when "100011" =>
          -- pout/leds/debug selector
          v.sel(0) := apbi.pwdata(3 downto 0);
          v.sel(1) := apbi.pwdata(7 downto 4);
          v.sel(2) := apbi.pwdata(11 downto 8);
          v.sel(3) := apbi.pwdata(15 downto 12);
          v.sel(4) := apbi.pwdata(19 downto 16);
          v.sel(5) := apbi.pwdata(23 downto 20);
          v.sel(6) := apbi.pwdata(27 downto 24);
          v.sel(7) := apbi.pwdata(31 downto 28);
        when "100100" =>
          -- pout/leds/debug selector
          v.sel(8) := apbi.pwdata(3 downto 0);
          v.sel(9) := apbi.pwdata(7 downto 4);
          v.sel(10) := apbi.pwdata(11 downto 8);
          v.sel(11) := apbi.pwdata(15 downto 12);
          v.sel(12) := apbi.pwdata(19 downto 16);
          v.sel(13) := apbi.pwdata(23 downto 20);
          v.sel(14) := apbi.pwdata(27 downto 24);
          v.sel(15) := apbi.pwdata(31 downto 28);
        when "100101" =>
          -- pout/leds/debug selector
          v.sel(16) := apbi.pwdata(3 downto 0);
          v.sel(17) := apbi.pwdata(7 downto 4);
          v.sel(18) := apbi.pwdata(11 downto 8);
          v.sel(19) := apbi.pwdata(15 downto 12);
          v.sel(20) := apbi.pwdata(19 downto 16);
        when "000000" =>	-- 0
          v.mode(0) := apbi.pwdata(6 downto 0);
        when "000001" =>	-- 1
          v.mode(1) := apbi.pwdata(6 downto 0);
        when "000010" =>	-- 2
          v.mode(2) := apbi.pwdata(6 downto 0);
        when "000011" =>	-- 3
          v.mode(3) := apbi.pwdata(6 downto 0);
        when "000100" =>	-- 4
          v.mode(4) := apbi.pwdata(6 downto 0);
        when "000101" =>	-- 5
          v.mode(5) := apbi.pwdata(6 downto 0);
        when "000110" =>	-- 6
          v.mode(6) := apbi.pwdata(6 downto 0);
        when "000111" =>	-- 7
          v.mode(7) := apbi.pwdata(6 downto 0);
        when "001000" =>	-- 8
          v.mode(8) := apbi.pwdata(6 downto 0);
        when "001001" =>	-- 9
          v.mode(9) := apbi.pwdata(6 downto 0);
        when "001010" =>	-- 10
          v.mode(10) := apbi.pwdata(6 downto 0);
        when "001011" =>	-- 11
          v.mode(11) := apbi.pwdata(6 downto 0);
        when "001100" =>	-- 12
          v.mode(12) := apbi.pwdata(6 downto 0);
        when "001101" =>	-- 13
          v.mode(13) := apbi.pwdata(6 downto 0);
        when "001110" =>	-- 14
          v.mode(14) := apbi.pwdata(6 downto 0);
        when "001111" =>	-- 15
          v.mode(15) := apbi.pwdata(6 downto 0);
        when "010000" =>	-- 16
          v.mode(16) := apbi.pwdata(6 downto 0);
        when "010001" =>	-- 17
          v.mode(17) := apbi.pwdata(6 downto 0);
        when "010010" =>	-- 18
          v.mode(18) := apbi.pwdata(6 downto 0);
        when "010011" =>	-- 19
          v.mode(19) := apbi.pwdata(6 downto 0);
        when "010100" =>	-- 20
          v.mode(20) := apbi.pwdata(6 downto 0);
        when others => null;
      end case;
      --pragma translate_off
      if (unsigned(apbi.paddr(7 downto 2)) >= 0 and unsigned(apbi.paddr(7 downto 2)) <= 20) then
	-- connect pwadata bit per bit to view true bus value in the console
	print("-I- gpio(" & tostd(apbi.paddr(7 downto 2)) & "):: " & tostb(apbi.pwdata(6)&apbi.pwdata(5)&apbi.pwdata(4)&apbi.pwdata(3)&
	                                                                   apbi.pwdata(2)&apbi.pwdata(1)&apbi.pwdata(0)) );
      end if;
      --pragma translate_on
    end if;

-- interrupt generation

    for i in 0 to 3 loop	-- select and latch interrupt source
      v.irqlat(i) := genmux(r.iconf(i).isel, r.pin2);

      if r.iconf(i).enable = '1' then
      	if r.iconf(i).edge = '1' then
	  v.irqout(i) := (v.irqlat(i) xor r.irqlat(i)) and
                         (v.irqlat(i) xor not r.iconf(i).pol);
        else
	  v.irqout(i) := (v.irqlat(i) xor not r.iconf(i).pol);
	end if;
      else
	v.irqout(i) := '0';
      end if;
    end loop;

    leds_debug := leds & debug & '0';
    v.po := (others => '0');
    for i in 0 to IO_MAX-1 loop
      leds_debug(0) := r.pout(i);
-- pragma translate_off
      if not is_x(r.sel(i)) then
-- pragma translate_on
        v.po(i) := leds_debug(to_integer(unsigned(r.sel(i))));
-- pragma translate_off
      else
        v.po(i) := 'X';
      end if;
-- pragma translate_on
    end loop;

-- drive signals
    rin		<= v; 		-- update registers
    apbo.prdata <= rdata; 	-- drive data bus
    irqout      <= r.irqout;
    pdir        <= r.pdir;
    po          <= r.po;
    mode	<= r.mode;

  end process;

-- registers

  regs : process(clk,rst)
  begin
    if rst = '0' then
      r.pout <= (others => '0');
      r.po <= (others => '0');
      r.irqout <= (others => '0');
      r.pdir <= (others => '1');	--default direction=IN
      r.iconf(0).enable <= '0';
      r.iconf(1).enable <= '0';
      r.iconf(2).enable <= '0';
      r.iconf(3).enable <= '0';
      r.mode(0) <=  "1100000";	-- 0x60
      r.mode(1) <=  "1100000";	-- 0x60
      r.mode(2) <=  "1100000";	-- 0x60
      r.mode(3) <=  "1100000";	-- 0x60
      r.mode(4) <=  "1100000";	-- 0x60
      r.mode(5) <=  "1100000";	-- 0x60
      r.mode(6) <=  "1100000";	-- 0x60
      r.mode(7) <=  "1100000";	-- 0x60
      r.mode(8) <=  "1110000";	-- 0x70
      r.mode(9) <=  "1111010";	-- 0x7A
      r.mode(10) <= "1111010";	-- 0x7A
      r.mode(11) <= "1111010";	-- 0x7A
      r.mode(12) <= "1101010";	-- 0x6A
      r.mode(13) <= "1101010";	-- 0x6A
      r.mode(14) <= "1101010";	-- 0x6A
      r.mode(15) <= "1101010";	-- 0x6A
      r.mode(16) <= "1101010";	-- 0x6A
      r.mode(17) <= "1101010";	-- 0x6A
      r.mode(18) <= "1100000";	-- 0x60
      r.mode(19) <= "1100000";	-- 0x60
      r.mode(20) <= "1100000";	-- 0x60
      r.sel(0) <= "0000";	-- pout(0)
      r.sel(1) <= "0000";	-- pout(1)
      r.sel(2) <= "0000";	-- pout(2)
      r.sel(3) <= "1000";	-- leds(0)	<< connect debug led on gpio3 port >>
      r.sel(4) <= "0000";	-- pout(4)
      r.sel(5) <= "0000";	-- pout(5)
      r.sel(6) <= "0000";	-- pout(6)
      r.sel(7) <= "0000";	-- pout(7)
      r.sel(8) <= "0000";	-- pout(8)
      r.sel(9) <= "0000";	-- pout(9)
      r.sel(10) <= "0000";	-- pout(10)
      r.sel(11) <= "0000";	-- pout(11)
      r.sel(12) <= "0000";	-- pout(12)
      r.sel(13) <= "0000";	-- pout(13)
      r.sel(14) <= "0000";	-- pout(14)
      r.sel(15) <= "0000";	-- pout(15)
      r.sel(16) <= "0000";	-- pout(16)
      r.sel(17) <= "0000";	-- pout(17)
      r.sel(18) <= "0000";	-- pout(18)
      r.sel(19) <= "0000";	-- pout(19)
      r.sel(20) <= "0000";	-- pout(20)
    elsif rising_edge(clk) then
      r <= rin;
    end if;
  end process;


end;
