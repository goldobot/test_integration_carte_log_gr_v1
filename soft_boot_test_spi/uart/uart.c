#include "uart.h"
#include "leon.h"
#include "timer.h"

#include "config.h"

#ifndef CPU_FREQUENCY
#error "CPU_FREQUENCY not defined"
#endif

/* Baud-rate generation */
/* Each UART contains a 12-bit down-counting scaler to generate the
   desired baud-rate. The scaler is clocked by the system clock and
   generates a UART tick each time it underflows. The scaler is reloaded
   with the value of the UART scaler reload register after each
   underflow. The resulting UART tick frequency should be 8 times the
   desired baud-rate. If the EC bit is set, the scaler will be clocked
   by the PIO[3] input rather than the system clock. In this case, the
   frequency of PIO[3] must be less than half the frequency of the
   system clock. */

/* #define B115200 (( CPU_FREQUENCY / 115200 ) / 8 ) */
/* #define B57600  (( CPU_FREQUENCY /  57600 ) / 8 ) */
/* #define B38400  (( CPU_FREQUENCY /  38400 ) / 8 ) */
/* #define B19200  (( CPU_FREQUENCY /  19200 ) / 8 ) */
/* #define B9600   (( CPU_FREQUENCY /   9600 ) / 8 ) */

#define BAUDRATE( n$ ) (( CPU_FREQUENCY / ( n$ )) / 8 )

typedef struct {
    uint8_t buffer[256];
    uint8_t write_idx;
    uint8_t read_idx;
} uart_fifo_t;

uart_fifo_t uart1_fifo;

struct baudrate_conv {
    enum uart_baudrate_t bd;
    uint32_t scaler;
};

static enum uart_parity_t parity = PARITY_ODD;

static struct baudrate_conv uart_baudrate_table[] =
{
    { B9600,     BAUDRATE (   9600 ) },
    { B19200,    BAUDRATE (  19200 ) },
    { B38400,    BAUDRATE (  38400 ) },
    { B57600,    BAUDRATE (  57600 ) },
    { B115200,   BAUDRATE ( 115200 ) },
    { BAUTOBAUD, BAUDRATE ( 115200 ) }
};

#define arraysizeof( a$ ) ( sizeof ( a$ ) / sizeof ( a$[0]))

static int uart_get_baudrate_idx ( enum uart_baudrate_t bd ) {
    for ( int i = 0; i < arraysizeof ( uart_baudrate_table ); i++ ) {
        if ( uart_baudrate_table[i].bd == bd ) {
            return i;
        }
    }
    return -1;
}

enum uart_parity_t uart_get_parity () {
    return parity;
}

void uart_set_parity ( enum uart_parity_t p ) {
    parity = p;
}

static int uart_get_parity_control () {
    switch ( parity ) {
    case PARITY_NONE:
        return 0;
    case PARITY_EVEN:
        return UART_CONTROL_PE;
    case PARITY_ODD:
    default:
        return UART_CONTROL_PE | UART_CONTROL_PS;
    }
}

uint32_t uart_get_scaler ( enum uart_baudrate_t bd ) {
    int idx = uart_get_baudrate_idx ( bd );
    if ( idx == -1 ) {
        idx = 0;
    }
    return uart_baudrate_table[idx].scaler;
}

void uart_set_scaler ( enum uart_baudrate_t bd, uint32_t scaler ) {
    int idx = uart_get_baudrate_idx ( bd );
    if ( idx == -1 ) {
        return;
    }
    uart_baudrate_table[idx].scaler = scaler;
}

static void uart_init_lowlevel ( int scaler, int ctrl ) {
    struct lregs *hw = ( struct lregs * )( PREGS );
    hw->irqmask &= ~( 1 << IRQ_UART1 );

    hw->uartscaler1 = scaler;
    hw->uartctrl1   = ctrl | UART_CONTROL_RI;
    uart1_fifo.read_idx  = 0;
    uart1_fifo.write_idx = 0;

    hw->irqmask |= ( 1 << IRQ_UART1 );
}

#if 0
void uart_calibrate () {
    struct lregs *hw = ( struct lregs * )( PREGS );
    hw->irqmask &= ~( 1 << IRQ_UART1 ); // CAUTION: interruptions disabled but never re-enabled! (FF)

    if ( hw->uartctrl1 & UART_CONTROL_TE ) {
        uart_flush ();
    }

    hw->uartscaler1 = 1;
    hw->uartstatus1 = 0x80; // reset autobaud
    hw->uartctrl1   = uart_get_parity_control () | UART_CONTROL_RE | UART_CONTROL_EC;

    while ( !( hw->uartstatus1 & UART_STATUS_AL ));
    hw->uartctrl1 &= ~UART_CONTROL_EC;

    uint32_t sclr = (( hw->uartctrl1 ) >> 16 ) - 1;
    uart_set_scaler ( BAUTOBAUD, sclr );

    uint8_t byte = hw->uartdata1;

    while ( hw->uartstatus1 & UART_STATUS_DR ) {
        byte = hw->uartdata1;
    }
    ( void ) byte;

    hw->uartctrl1 = 0;
}
#endif

void uart_init ( enum uart_baudrate_t bd ) {
    int ctrl = uart_get_parity_control () | UART_CONTROL_RE | UART_CONTROL_TE | UART_CONTROL_RI;

/* FIXME : DEBUG + */
    /* Contournement pour un bug d'init de la section .data */
    uart_baudrate_table[0].bd     = B9600;
    uart_baudrate_table[0].scaler = BAUDRATE (   9600 );
    uart_baudrate_table[0].bd     = B19200;
    uart_baudrate_table[0].scaler = BAUDRATE (  19200 );
    uart_baudrate_table[0].bd     = B38400;
    uart_baudrate_table[0].scaler = BAUDRATE (  38400 );
    uart_baudrate_table[0].bd     = B57600;
    uart_baudrate_table[0].scaler = BAUDRATE (  57600 );
    uart_baudrate_table[0].bd     = B115200;
    uart_baudrate_table[0].scaler = BAUDRATE ( 115200 );
    uart_baudrate_table[0].bd     = BAUTOBAUD;
    uart_baudrate_table[0].scaler = BAUDRATE ( 115200 );
/* FIXME : DEBUG - */

    uart_init_lowlevel ( uart_get_scaler ( bd ), ctrl );
}

void uart_flush () {
    struct lregs *hw = ( struct lregs * )( PREGS );

    while (( hw->uartstatus1 & ( UART_STATUS_TS | UART_STATUS_TH )) != ( UART_STATUS_TS | UART_STATUS_TH ));
}

void uart_putchar ( uint8_t byte ) {
    struct lregs *hw = ( struct lregs * )( PREGS );

    /* wait until transmitter hold register is empty */
    while ( ! ( hw->uartstatus1 & UART_STATUS_TH )) {
    }

    hw->uartdata1 = ( unsigned int ) byte;
}

int uart_getchar_in_fifo ( uint8_t *byte ) {
    int ok = 0;
    if ( uart1_fifo.write_idx != uart1_fifo.read_idx ) {
        *byte = uart1_fifo.buffer[uart1_fifo.read_idx++];
        ok = 1;
    }
    return ok;
}

uint8_t uart_getchar () {
    uint8_t byte;
    while ( !uart_getchar_in_fifo ( &byte )) {
    }
    return byte;
}

#if 0
int uart_try_getchar ( unsigned int time_ms, uint8_t *byte ) {
    int ok = 0;

    timer_enable ();
    do {
        if ( uart_getchar_in_fifo ( byte )) {
            ok = 1;
            break;
        }
    } while ( timer_counter < ( uint32_t ) time_ms );
    timer_disable ();

    return ok;
}
#endif

#define UART_MAX_STRING 256
void uart_putstring ( uint8_t *s ) {
  int i;

  for (i=0; i<UART_MAX_STRING; i++) {
    if (s[i]==0x00) break;
    uart_putchar ( s[i] );
  }
}

void uart_printhex ( uint32_t val ) {
  int i;
  uint32_t lval, pval;

  lval = val;
  for (i=0; i<8; i++) {
    pval = lval & 0xf0000000;
    lval = lval << 4;
    pval = pval >> 28;
    if (pval<10)
      uart_putchar ( '0'+pval );
    else
      uart_putchar ( 'a'+pval-10 );
  }
}

char print_s[16];

void uart_printint ( int val ) {
  uint32_t abs_val, abs_val_save, divisor, quot, shift;
  uint32_t high_zero, nchar, i;
  uint32_t *work_p;

  if (val==0) {
    uart_putchar ( '0' );
    nchar = 1;
    goto out;
  }

  nchar = 0;

  if (val<0) {
    abs_val = -val;
    uart_putchar ( '-' );
    nchar++;
  } else {
    abs_val = val;
  }
  abs_val_save = abs_val;

  work_p = (unsigned int *) ((void *)&print_s[0]);
  work_p[0]=0;
  work_p[1]=0;
  work_p[2]=0;
  work_p[3]=0;
  divisor = 1000000000;
  shift = 0;
  high_zero = 1;
  while (divisor>0) {
    quot = abs_val / divisor;
    abs_val = abs_val - (quot*divisor);
    divisor = divisor / 10;
    if (quot==0) {
      if (high_zero==1) continue;
    } else {
      high_zero=0;
    }
    *work_p = (((*work_p)<<8) & 0xffffff00) | ((0x30 + quot));
    nchar++;
    shift += 8;
    if (shift==32) {
      work_p++;
      shift=0;
    }
  }

  while (shift!=32) {
    shift += 8;
    *work_p = (((*work_p)<<8) & 0xffffff00);
  }

  uart_putstring ( print_s );

 out:
  for (i=nchar; i<11; i++) {
    uart_putchar ( ' ' );
  }
}


