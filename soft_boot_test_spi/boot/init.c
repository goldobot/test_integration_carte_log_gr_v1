#include "leon.h"

/* Cache Control Register */
#define CCR_DCS_DIS ( 0x0 << 2 )
#define CCR_DCS_FRZ ( 0x1 << 2 )
#define CCR_DCS_ENA ( 0x3 << 2 )
#define CCR_ICS_DIS 0x0
#define CCR_ICS_FRZ 0x1
#define CCR_ICS_ENA 0x3
#define CCR_IB ( 1<<16 )
#define CCR_DS ( 1<<23 )

#define MCFG1_WDTH_MSK ( 0x3 << 8 )
#define MCFG1_WR_MSK ( 0xf << 4 )
#define MCFG1_RD_MSK 0xf
#define MCFG1_IO_READY_ENA ( 1 << 26 )
#define MCFG1_IO_ENA ( 1 << 19 )
#define MCFG1_IO_RD( n )  (( n ) & 0xf )
#define MCFG1_IO_WR( n ) ((( n ) & 0xf ) << 4 )

#define MCFG2_REFRESH_ENA ( 1 << 31 )
#define MCFG2_T_RP2 ( 0 << 30 )
#define MCFG2_T_RP3 ( 1 << 30 )
#define MCFG2_T_RFC( n ) (((( n ) - 3 ) & 0x7 ) << 27 )
#define MCFG2_T_RCD2 ( 0 << 26 )
#define MCFG2_T_RCD3 ( 1 << 26 )
#define MCFG2_SDRAM_BANK_4MB   ( 0x0 << 23 )
#define MCFG2_SDRAM_BANK_8MB   ( 0x1 << 23 )
#define MCFG2_SDRAM_BANK_16MB  ( 0x2 << 23 )
#define MCFG2_SDRAM_BANK_32MB  ( 0x3 << 23 )
#define MCFG2_SDRAM_BANK_64MB  ( 0x4 << 23 )
#define MCFG2_SDRAM_BANK_128MB ( 0x5 << 23 )
#define MCFG2_SDRAM_BANK_256MB ( 0x6 << 23 )
#define MCFG2_SDRAM_BANK_512MB ( 0x7 << 23 )
#define MCFG2_COL_256  ( 0x0 << 21 )
#define MCFG2_COL_512  ( 0x1 << 21 )
#define MCFG2_COL_1024 ( 0x2 << 21 )
#define MCFG2_COL_2048 ( 0x3 << 21 )
#define MCFG2_COL_4096 ( 0x3 << 21 )
#define MCFG2_CMD_NONE ( 0x0 << 19 )
#define MCFG2_CMD_PRE  ( 0x1 << 19 )
#define MCFG2_CMD_AUTO ( 0x2 << 19 )
#define MCFG2_CMD_LOAD ( 0x3 << 19 )
#define MCFG2_SE ( 1 << 14 )
#define MCFG2_SI ( 1 << 13 )
#define MCFG2_SRAM_BANK_8K    ( 0x0 << 9 )
#define MCFG2_SRAM_BANK_16K   ( 0x1 << 9 )
#define MCFG2_SRAM_BANK_32K   ( 0x2 << 9 )
#define MCFG2_SRAM_BANK_64K   ( 0x3 << 9 )
#define MCFG2_SRAM_BANK_128K  ( 0x4 << 9 )
#define MCFG2_SRAM_BANK_256K  ( 0x5 << 9 )
#define MCFG2_SRAM_BANK_512K  ( 0x6 << 9 )
#define MCFG2_SRAM_BANK_1MB   ( 0x7 << 9 )
#define MCFG2_SRAM_BANK_2MB   ( 0x8 << 9 )
#define MCFG2_SRAM_BANK_4MB   ( 0x9 << 9 )
#define MCFG2_SRAM_BANK_8MB   ( 0xa << 9 )
#define MCFG2_SRAM_BANK_16MB  ( 0xb << 9 )
#define MCFG2_SRAM_BANK_32MB  ( 0xc << 9 )
#define MCFG2_SRAM_BANK_64MB  ( 0xd << 9 )
#define MCFG2_SRAM_BANK_128MB ( 0xe << 9 )
#define MCFG2_SRAM_BANK_256MB ( 0xf << 9 )
#define MCFG2_BRDYN_ENA ( 1 << 7 )
#define MCFG2_RMW ( 1 << 6 )
#define MCFG2_RAM_WDTH( n ) ((( n ) & 0x3 ) << 4 )
#define MCFG2_RAM_WR( n )   ((( n ) & 0x3 ) << 2 )
#define MCFG2_RAM_RD( n )    (( n ) & 0x3 )
#define MCFG2_SRAM_BANK_MSK ( 0xf << 9 )

void _init_peripherals () {
    struct lregs *hw = ( struct lregs * )( PREGS );
    /* FIXME : DEBUG */
    //hw->cachectrl = CCR_DS|CCR_IB|CCR_DCS_ENA|CCR_ICS_ENA;

#if 0 /* FIXME : DEBUG */
    /* Don't know what this piece of code does */
    {
        unsigned int tmp = hw->ectrl;
        tmp &= 0x100;
        tmp |= tmp << 1;
        tmp |= 0x0f0000;
        hw->ectrl = tmp;
    }

    {
        unsigned int tmp1 = hw->memcfg1;
        tmp1 &= MCFG1_WDTH_MSK|MCFG1_WR_MSK|MCFG1_RD_MSK;
        hw->memcfg1 = tmp1;

        unsigned int tmp2 = hw->piodata;
        tmp1 &= MCFG1_WDTH_MSK;
        tmp1 |= ( tmp2 >> 4 ) & 0x3;
        tmp1 |= MCFG1_IO_READY_ENA|MCFG1_IO_ENA|MCFG1_IO_WR ( 1 )|MCFG1_IO_RD ( 1 );
        hw->memcfg1 = tmp1;

        unsigned int tmp3 = tmp2 << 4;
        tmp1   = tmp3 & 0x70;
        tmp3   = tmp2 & 0xc0;
        tmp3 >>= 4;
        tmp1  |= tmp3;
        tmp3 >>= 2;
        tmp1  |= tmp3;
        tmp1  |= 0x800;
        if ( tmp2 & 0x3 ) {
            tmp1 += 0x200;
        }
        tmp1 |=
            MCFG2_REFRESH_ENA|MCFG2_T_RP3|MCFG2_T_RFC ( 5 )|
            MCFG2_T_RCD3|MCFG2_SDRAM_BANK_16MB|MCFG2_COL_512|
            MCFG2_CMD_LOAD|MCFG2_SE|MCFG2_SRAM_BANK_256MB|
            MCFG2_RAM_WDTH ( 3 )|MCFG2_RAM_WR ( 1 )|MCFG2_RAM_RD ( 1 );
        tmp1 &= (~MCFG2_SRAM_BANK_MSK ) | MCFG2_SRAM_BANK_64K;
        hw->memcfg2 = tmp1;
    }
#endif /* FIXME : DEBUG */

    hw->failaddr = 0;

    hw->memstatus = 0;

    hw->writeprot1 = 0;
    hw->writeprot2 = 0;

    hw->scalerload = -1;
    hw->scalercnt  = -1;

    hw->timerctrl1 =  0;
    hw->timerload1 = -1;
    hw->timercnt1  = -1;

    hw->timerctrl2 =  0;
    hw->timerload2 = -1;
    hw->timercnt2  = -1;

    hw->uartscaler1 = -1;
    hw->uartctrl1   = -1;
    hw->uartstatus1 =  0;

    hw->uartscaler2 = -1;
    hw->uartctrl2   = -1;
    hw->uartstatus2 =  0;

    hw->writeprot1 = 0; // why clearing them again?
    hw->writeprot2 = 0;

    hw->piodata = 0;
    hw->pioirq  = 0;

    hw->irqforce =  0;
    hw->irqmask  =  0;
    hw->irqpend  =  0;
    hw->irqclear = -1;

    hw->imask2 =  0;
    hw->ipend2 =  0;
    hw->istat2 = -1; // iclear2
    hw->istat2 =  0;
}

extern unsigned char _rom_rodata_end;
extern unsigned char _rom_data_start;
extern unsigned char _rom_data_end;
extern unsigned char _rom_bss_start;
extern unsigned char _rom_bss_end;

void _init_rom_data_bss () {
    {
        /* Copy ROM data section into RAM */
        unsigned char *src = &_rom_rodata_end;
        unsigned char *dst = &_rom_data_start;
        while ( dst < &_rom_data_end ) {
            *dst++ = *src++;
        }
    }

    /* Clear ROM bss */
    for ( unsigned char *dst = &_rom_bss_start; dst < &_rom_bss_end; dst++) {
        *dst = 0;
    }
}
