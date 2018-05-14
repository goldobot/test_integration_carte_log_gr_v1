



----------------------------------------------------------------------------
--  This file is a part of the LEON VHDL model
--  Copyright (C) 1999  European Space Agency (ESA)
--
--  This library is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Lesser General Public
--  License as published by the Free Software Foundation; either
--  version 2 of the License, or (at your option) any later version.
--
--  See the file COPYING.LGPL for the full details of the license.


-----------------------------------------------------------------------------
-- Entity: 	ambacomp
-- File:	ambacomp.vhd
-- Author:	Jiri Gaisler - ESA/ESTEC
-- Description:	Component declarations of AMBA cores
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.amba.all;
use work.target.all;
use work.config.all;
use work.iface.all;

package ambacomp is

-- processor core

  component proc
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      clkn   : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbi   : in  ahb_mst_in_type;
      ahbo   : out ahb_mst_out_type;
      ahbsi  : in  ahb_slv_in_type;
      iui    : in  iu_in_type;
      iuo    : out iu_out_type
      );
  end component;

-- AMBA/PCI interface for InSilicon (was Phoenix) PCI core
  component pci_is
    port (
      rst_n           : in  std_logic;
      pciresetn       : in  std_logic;
      app_clk         : in  clk_type;
      pci_clk         : in  clk_type;
      pbi             : in  APB_Slv_In_Type;   -- peripheral bus in
      pbo             : out APB_Slv_Out_Type;  -- peripheral bus out
      irq             : out std_logic;         -- interrupt request
      TargetMasterOut : out ahb_mst_out_type;  -- PCI target DMA
      TargetMasterIn  : in  ahb_mst_in_type;
      pci_in          : in  pci_in_type;       -- PCI pad inputs
      pci_out         : out pci_out_type;      -- PCI pad outputs
      InitSlaveOut  : out ahb_slv_out_type;  	-- Direct PCI master access
      InitSlaveIn   : in  ahb_slv_in_type;
      InitMasterOut : out ahb_mst_out_type;  	-- PCI Master DMA
      InitMasterIn  : in  ahb_mst_in_type
      );
  end component;

-- ESA PCI interface
  component pci_esa
    port (
      resetn          : in  std_logic;         -- Amba reset signal
      app_clk         : in  clk_type;          -- Application clock
      pci_in          : in  pci_in_type;       -- PCI pad inputs
      pci_out         : out pci_out_type;      -- PCI pad outputs
      ahbmasterin     : in  ahb_mst_in_type;   -- AHB Master inputs
      ahbmasterout    : out ahb_mst_out_type;  -- AHB Master outputs
      ahbslavein      : in  ahb_slv_in_type;   -- AHB Slave inputs
      ahbslaveout     : out ahb_slv_out_type;  -- AHB Slave outputs
      apbslavein      : in  apb_Slv_In_Type;   -- peripheral bus in
      apbslaveout     : out apb_Slv_Out_Type;  -- peripheral bus out
      irq             : out std_logic          -- interrupt request
      );
  end component;

-- Non-functional PCI module for testing
  component pci_test
    port (
      rst    : in  std_logic;
      clk    : in  std_logic;
      ahbmi  : in  ahb_mst_in_type;
      ahbmo  : out ahb_mst_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type
      );
  end component;

-- PCI arbiter

  component pci_arb
    port (
      clk     : in  clk_type ;                              -- clock
      rst_n   : in  std_logic;                           -- async reset active low
      req_n   : in  std_logic_vector(0 to NB_AGENTS-1);  -- bus request
      frame_n : in  std_logic;
      gnt_n   : out std_logic_vector(0 to NB_AGENTS-1);  -- bus grant
      pclk    : in  clk_type;                            -- APB clock
      prst_n  : in  std_logic;                           -- APB reset
      pbi     : in  APB_Slv_In_Type;                     -- APB inputs
      pbo     : out APB_Slv_Out_Type
      );
  end component;


-- APB/AHB bridge

  component apbmst
    generic (apbmax : integer := 15);
    port (
      rst     : in  std_logic;
      clk     : in  clk_type;
      ahbi    : in  ahb_slv_in_type;
      ahbo    : out ahb_slv_out_type;
      apbi    : out apb_slv_in_vector(0 to APB_SLV_MAX-1);
      apbo    : in  apb_slv_out_vector(0 to APB_SLV_MAX-1)
      );
  end component;

-- AHB arbiter

  component ahbarb
    generic (
      masters : integer := 2;		-- number of masters
      defmast : integer := 0 		-- default master
      );
    port (
      rst     : in  std_logic;
      clk     : in  clk_type;
      msti    : out ahb_mst_in_vector(0 to masters-1);
      msto    : in  ahb_mst_out_vector(0 to masters-1);
      slvi    : out ahb_slv_in_vector(0 to AHB_SLV_MAX-1);
      slvo    : in  ahb_slv_out_vector(0 to AHB_SLV_MAX)
      );
  end component;

-- PROM/SRAM controller

  component mctrl
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      memi   : in  memory_in_type;
      memo   : out memory_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      wpo    : in  wprot_out_type;
      mctrlo : out mctrl_out_type
      );
  end component;

-- AHB test module

  component ahbtest
    port (
      rst  : in  std_logic;
      clk  : in  clk_type;
      ahbi : in  ahb_slv_in_type;
      ahbo : out ahb_slv_out_type
      );
  end component;

-- AHB write-protection module

  component wprot
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      wpo    : out wprot_out_type;
      ahbsi  : in  ahb_slv_in_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type
      );
  end component;

-- AHB status register

  component ahbstat
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      ahbmi  : in  ahb_mst_in_type;
      ahbsi  : in  ahb_slv_in_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbsto : out ahbstat_out_type

      );
  end component;

-- LEON configuration register

  component lconf
    port (
      rst    : in  std_logic;
      apbo   : out apb_slv_out_type
      );
  end component;

-- interrupt controller

  component irqctrl
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      irqi   : in  irq_in_type;
      irqo   : out irq_out_type
      );
  end component;

-- secondary interrupt controller

  component irqctrl2
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      irqi   : in  irq2_in_type;
      irqo   : out irq2_out_type
      );
  end component;

-- timers module

  component timers
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      timo   : out timers_out_type
      );
  end component;

-- UART

  component uart
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      uarti  : in  uart_in_type;
      uarto  : out uart_out_type
      );
  end component;

-- I/O port

  component ioport
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      uart1o : in  uart_out_type;
      uart2o : in  uart_out_type;
      mctrlo : in  mctrl_out_type;
      ioi    : in  io_in_type;
      pioo   : out pio_out_type
      );
  end component;

-- Generic AHB master

  component ahbmst
    generic (incaddr : integer := 0);
    port (
      rst  : in  std_logic;
      clk  : in  clk_type;
      dmai : in ahb_dma_in_type;
      dmao : out ahb_dma_out_type;
      ahbi : in  ahb_mst_in_type;
      ahbo : out ahb_mst_out_type
      );
  end component;

-- DMA

  component dma
    port (
      rst  : in  std_logic;
      clk  : in  clk_type;
      dirq  : out std_logic;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbi : in  ahb_mst_in_type;
      ahbo : out ahb_mst_out_type
      );
  end component;

  component pci_actel
    generic (
      USER_DEVICE_ID  : integer := 0;
      USER_VENDOR_ID  : integer := 0;
      USER_REVISION_ID: integer := 0;
      USER_BASE_CLASS : integer := 0;
      USER_SUB_CLASS  : integer := 0;
      USER_PROGRAM_IF : integer := 0;
      USER_SUBSYSTEM_ID : integer := 0;
      USER_SUBVENDOR_ID : integer := 0

--      ;BIT_64          : STD_LOGIC := '0';
--      MHZ_66          : STD_LOGIC := '0';
--      DMA_IN_IO       : STD_LOGIC := '1';
--      MADDR_WIDTH     : INTEGER RANGE 4 TO 31 := 22;
--      BAR1_ENABLE     : STD_LOGIC := '0';
--      BAR1_IO_MEMORY  : STD_LOGIC := '0';
--      BAR1_ADDR_WIDTH : INTEGER RANGE 2 TO 31 := 12;
--      BAR1_PREFETCH   : STD_LOGIC := '0';
--      HOT_SWAP_ENABLE : STD_LOGIC := '0'
      );
    port(

      clk           : in std_logic;
      rst           : in std_logic;
      -- PCI signals

      pcii	: in  pci_in_type;
      pcio	: out pci_out_type;

      ahbmi 	: in  ahb_mst_in_type;
      ahbmo 	: out ahb_mst_out_type;
      ahbsi 	: in  ahb_slv_in_type;
      ahbso 	: out ahb_slv_out_type
      );
  end component;

-- ACTEL PCI target backend

  component pci_be_actel
    port (
      rst  : in  std_logic;
      clk  : in  std_logic;
      ahbmi : in  ahb_mst_in_type;
      ahbmo : out ahb_mst_out_type;
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;
      bei  : in  actpci_be_in_type;
      beo  : out actpci_be_out_type
      );
  end component;

-- opencores pci interface

  component pci_oc
    port (
      rst  : in  std_logic;
      clk  : in  std_logic;
      pci_clk : in std_logic;
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;
      ahbmi : in  ahb_mst_in_type;
      ahbmo : out ahb_mst_out_type;
      apbi  : in  apb_slv_in_type;
      apbo  : out apb_slv_out_type;
      pcio  : out pci_out_type;
      pcii  : in  pci_in_type;
      irq   : out std_logic
      );
  end component;

-- generic pci interface

  component pci
    port (
      resetn : in  std_logic;
      clk    : in  clk_type;
      pciclk : in  clk_type;
      pcirst : in  std_logic;
      pcii   : in  pci_in_type;
      pcio   : out pci_out_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbmi1 : in  ahb_mst_in_type;
      ahbmo1 : out ahb_mst_out_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      irq    : out std_logic
      );
  end component;

-- debug support unit

  component dsu
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      ahbmi  : in  ahb_mst_in_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type;
      dsui   : in  dsu_in_type;
      dsuo   : out dsu_out_type;
      dbgi   : in  iu_debug_out_type;
      dbgo   : out iu_debug_in_type;
      irqo   : in  irq_out_type;
      dmi    : out dsumem_in_type;
      dmo    : in  dsumem_out_type
      );
  end component;

  component dcom
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      dcomi  : in  dcom_in_type;
      dcomo  : out dcom_out_type;
      dsuo   : in  dsu_out_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      ahbi : in  ahb_mst_in_type;
      ahbo : out ahb_mst_out_type
      );
  end component;

  component dcom_uart
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      apbi   : in  apb_slv_in_type;
      apbo   : out apb_slv_out_type;
      uarti  : in  dcom_uart_in_type;
      uarto  : out dcom_uart_out_type
      );
  end component;

  component ahbram
    generic ( abits : integer := 10);
    port (
      rst    : in  std_logic;
      clk    : in  clk_type;
      ahbsi  : in  ahb_slv_in_type;
      ahbso  : out ahb_slv_out_type
      );
  end component;

  component eth_oc
    port (
      rst  : in  std_logic;
      clk  : in  std_logic;
      ahbsi : in  ahb_slv_in_type;
      ahbso : out ahb_slv_out_type;
      ahbmi : in  ahb_mst_in_type;
      ahbmo : out ahb_mst_out_type;
      eneti : in eth_in_type;
      eneto : out eth_out_type;
      irq   : out std_logic
      );
  end component;

  component pci_gr
    generic (device_id : integer := 0; vendor_id : integer := 0;
    nsync : integer := 1);
    port(
      rst       : in std_logic;
      pcirst    : in std_logic;
      clk       : in std_logic;
      pciclk    : in std_logic;
      pcii	: in  pci_in_type;
      pcio	: out pci_out_type;
      ahbmi 	: in  ahb_mst_in_type;
      ahbmo 	: out ahb_mst_out_type;
      ahbsi 	: in  ahb_slv_in_type;
      ahbso 	: out ahb_slv_out_type;
      apbi      : in  apb_slv_in_type;
      apbo      : out apb_slv_out_type
      );

  end component;

  component pci_mtf
    generic (
      abits     : integer := 21;
      fifobits  : integer := 3; -- FIFO depth
      device_id : integer := 0;		-- PCI device ID
      vendor_id : integer := 0;	        -- PCI vendor ID
      master    : integer := 1; 		-- Enable PCI Master
      nsync     : integer range 1 to 2 := 1	-- 1 or 2 sync regs between clocks
      );
    port(
      rst       : in std_logic;
      pcirst    : in std_logic;
      clk       : in std_logic;
      pciclk    : in std_logic;
      pcii      : in  pci_in_type;
      pcio      : out pci_out_type;
      ahbmi     : in  ahb_mst_in_type;
      ahbmo     : out ahb_mst_out_type;
      ahbsi     : in  ahb_slv_in_type;
      ahbso     : out ahb_slv_out_type;
      apbi      : in  apb_slv_in_type;
      apbo      : out apb_slv_out_type

      );
  end component;

  component leds_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; leds    : out std_logic_vector( 7 downto 0) -- 8 LEDS
          );
  end component;

  component leds_ahb is
    port (
      hclk    : in    std_logic;
      hresetn : in    std_logic;
      haddr   : in    std_logic_vector(31 downto 0);
      hsel    : in    std_logic;
      hwrite  : in    std_logic;
      hwdata  : in    std_logic_vector(31 downto 0);
      hready  : inout std_logic;
      hrdata  : out   std_logic_vector(31 downto 0);
      leds    : out   std_logic_vector( 7 downto 0)); -- 8 LEDS
  end component;

  component aes_128_fast_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component aes_256_fast_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component aes_128_fast_bcdl_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component aes_256_fast_bcdl_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component aesrsm_128_fast_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component aesrsm_256_fast_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component shield_apb
    port( pclk    : in  std_logic
          ; presetn : in  std_logic
          ; paddr   : in  std_logic_vector(31 downto 0)
          ; psel    : in  std_logic
          ; penable : in  std_logic
          ; pwrite  : in  std_logic
          ; pwdata  : in  std_logic_vector(31 downto 0)
          ; prdata  : out std_logic_vector(31 downto 0)
          ; sync    : out std_logic
          );
  end component;

  component iso7816_apb is
    port(	  pclk    : in  std_logic
                  ; presetn : in  std_logic
                  ; paddr   : in  std_logic_vector(31 downto 0)
                  ; psel    : in  std_logic
                  ; penable : in  std_logic
                  ; pwrite  : in  std_logic
                  ; pwdata  : in  std_logic_vector(31 downto 0)
                  ; prdata  : out std_logic_vector(31 downto 0)
                  ; irq	  : out std_logic
                  ; C2_n_resetsys : in std_logic
                  ; C3_clk  : in  std_logic
                  ; serialDataIn : in std_logic
                  ; serialDataOut : out std_logic
                  ; serialDataOutEnable : out std_logic
                  ; activation: out std_logic
                  );
  end component;

  component sha_apb is
    port( clk    : in  std_logic
          ; rst    : in  std_logic
          ; apbi   : in  apb_slv_in_type
          ; apbo   : out apb_slv_out_type
          );
  end component;

  component sha512_apb is
    port( clk    : in  std_logic
          ; rst    : in  std_logic
          ; apbi   : in  apb_slv_in_type
          ; apbo   : out apb_slv_out_type
          );
  end component;

  component des_ls_apb is
    port( clk    : in  std_logic
          ; rst    : in  std_logic
          ; apbi   : in  apb_slv_in_type
          ; apbo   : out apb_slv_out_type
          );
  end component;

  component delay_sensor_apb is
    generic(
      n_sensors : positive := 1);
    port (
      clk            : in  std_logic;
      rstn           : in  std_logic;
      apbi           : in  apb_slv_in_type;
      apbo           : out apb_slv_out_type;
      alarm_critical : out std_logic_vector(n_sensors-1 downto 0));
  end component;

  component rng is
    generic ( LENGTH : integer := 32);
    port( clk    : in  std_logic
          ; rst    : in  std_logic
          ; apbi   : in  apb_slv_in_type
          ; apbo   : out apb_slv_out_type
          );
  end component;

  component i2c_apb is
    port(
      --APB interface
      pclk    : in  std_logic
      ; presetn : in  std_logic
      ; paddr   : in  std_logic_vector(31 downto 0)
      ; psel    : in  std_logic
      ; penable : in  std_logic
      ; pwrite  : in  std_logic
      ; pwdata  : in  std_logic_vector(31 downto 0)
      ; prdata  : out std_logic_vector(31 downto 0)

      --I2C external signals
      ; sda_out : out std_logic
      ; sda_in  : in  std_logic
      ; sda_oe  : out std_logic
      ; scl_out : out std_logic
      ; scl_in  : in  std_logic
      ; scl_oe  : out std_logic

      ; irq     : out std_logic
      );
  end component;

  component i2c_master_top_apb is
    port   (
      clk_i	: in std_logic         -- clock
      ; rst_i	: in std_logic         -- reset (asynchronous active low)
      ; apbi   	: in  apb_slv_in_type
      ; apbo   	: out apb_slv_out_type
      ; irq	: out std_logic         -- interrupt output

      --I2C external signals
      ; sda_out : out std_logic
      ; sda_in  : in  std_logic
      ; sda_oe  : out std_logic
      ; scl_out : out std_logic
      ; scl_in  : in  std_logic
      ; scl_oe  : out std_logic
      );
  end component;

  component spi_apb is
    port (
      clk_i         : in std_logic         -- clock
      ; rst_i         : in std_logic         -- reset (asynchronous active low)
      ; apbi          : in  apb_slv_in_type
      ; apbo          : out apb_slv_out_type
      ; inta_o        : out std_logic         -- interrupt output

      -- SPI port
      ; sck_o         : out std_logic         -- serial clock output
      ; mosi_o        : out std_logic        -- MasterOut SlaveIN
      ; miso_i        : in std_logic        -- MasterIn SlaveOut
      );
  end component;

  component autobaud is
    generic (
      BAUD19200	: std_logic_vector(14 downto 0) := "000000001100111";
      SYN_NUM		: std_logic_vector(7 downto 0) := "00000100"
      );
    port (
      rst		: in	std_logic;
      clk		: in	std_logic;
      baud_rst	: in	std_logic;
      rxd		: in	std_logic;
      baud_out	: out	std_logic;
      lock	: out	std_logic;
      scale	: out	std_logic_vector(14 downto 0)
      );
  end component;


end;
