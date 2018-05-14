//-*-C++-*-

#include "uart.h"
#include "leds.h"
#include "sleep.h"
#include "leon.h"

#include "robot_leon.h"

/* FIXME : DEBUG : ne pas supprimer! */
unsigned int big_bad_buf[4] = {0};

uint8_t __attribute__ ((aligned (4))) uart_byte;

unsigned int i2c_test_data;

uint32_t read_test_32b (uint32_t *the_addr)
{
  register volatile uint32_t my_val32;
  register volatile uint32_t my_result;

  my_val32 = *the_addr;
  my_result = my_val32;

  return my_result;
}

void write_test_32b (uint32_t *the_addr, uint32_t the_val)
{
  register uint32_t my_val32;

  my_val32 = (uint32_t) the_val;
  *the_addr = my_val32;
}


#define INPUT_BUF_SZ 16
char input_buf[INPUT_BUF_SZ] = "0123456789012345";
int ib_index = 0;

#define IS_IDDLE     0
#define IS_WAIT_CMD  1
#define IS_EDIT_BUF  2

void print_input_buf()
{
  int i;
  int test_val;

  uart_putchar ( 0x0d );
  for (i=0; i<INPUT_BUF_SZ; i++) {
    test_val=input_buf[i];
    if ((test_val>=0x20) && (test_val<0x80))
      uart_putchar ( input_buf[i] );
    else
      uart_putchar ( '.' );
  }
}

int convert_input_buf_to_int()
{
  int i;
  int test_val;
  int result_val = 0;
  int result_sign = 1;
  int blank_space = 1;

  for (i=0; i<INPUT_BUF_SZ; i++) {
    test_val=input_buf[i];
    if ((test_val==0x20) || (test_val==0x5f)) { /* ' ' or '_' */
      if (blank_space) continue; else break;
    } else if (test_val==0x2d) { /* '-' */
      if (!blank_space) break;
      result_sign = -1;
      blank_space = 0;
    } else if ((test_val>=0x30) && (test_val<=0x39)) {
      result_val = result_val*10 + (test_val-0x30);
    } else {
      break;
    }
  }

  result_val = result_sign * result_val;

  return result_val;
}

int convert_input_buf_to_hexint()
{
  int i;
  int test_val;
  int result_val = 0;
  int result_sign = 1;
  int blank_space = 1;

  for (i=0; i<INPUT_BUF_SZ; i++) {
    test_val=input_buf[i];
    if ((test_val==0x20) || (test_val==0x5f)) { /* ' ' or '_' */
      if (blank_space) continue; else break;
    } else if (test_val==0x2d) { /* '-' */
      if (!blank_space) break;
      result_sign = -1;
      blank_space = 0;
    } else if ((test_val>=0x30) && (test_val<=0x39)) {
      result_val = result_val*16 + (test_val-0x30);
    } else if ((test_val>=0x41) && (test_val<=0x46)) {
      result_val = result_val*16 + (test_val-0x41) + 10;
    } else if ((test_val>=0x61) && (test_val<=0x66)) {
      result_val = result_val*16 + (test_val-0x61) + 10;
    } else {
      break;
    }
  }

  result_val = result_sign * result_val;

  return result_val;
}

void edit_input_buf ()
{
  struct lregs *hw = ( struct lregs * )( PREGS );
  volatile int* leds_reg = ( volatile int* ) LEDS_BASE_ADDR;
  unsigned int my_uartstatus1;
  unsigned int my_uartdata1;
  unsigned int mask = 0xff;
  unsigned int leds = mask;
  uint32_t *my_p;
  int i;

  for (i=0;i<INPUT_BUF_SZ;i++) {
    input_buf[i] = '_';
  }

  ib_index=0;

  for (;;) {

    my_uartstatus1 = hw->uartstatus1;
    if ( my_uartstatus1 & UART_STATUS_DR ) {
      my_uartdata1 = hw->uartdata1;
      uart_byte = my_uartdata1;

      if ((uart_byte=='>') || (uart_byte==0x0a) || (uart_byte==0x0d)) {
	uart_putchar ( '>' );
	uart_putchar ( 0xa );
	goto end;
      } else {
	unsigned int word_shift, byte_shift;
	unsigned int actual_val, local_mask, uart_val;

	//input_buf[ib_index++] = uart_byte;

	uart_putchar ( uart_byte );
	uart_val = uart_byte;

	word_shift = (ib_index>>2)<<2;
	byte_shift = ib_index - word_shift;
	switch (byte_shift) {
	case 0:
	  local_mask = 0x00ffffff;
	  uart_val = uart_val<<24;
	  break;
	case 1:
	  local_mask = 0xff00ffff;
	  uart_val = uart_val<<16;
	  break;
	case 2:
	  local_mask = 0xffff00ff;
	  uart_val = uart_val<<8;
	  break;
	case 3:
	  local_mask = 0xffffff00;
	  uart_val = uart_val<<0;
	  break;
	default:
	  local_mask = 0x00ffffff;
	  uart_val = uart_val<<24;
	} /* switch (byte_shift) */

	my_p = ((uint32_t *)((char *)input_buf+word_shift));
	actual_val = *my_p;
	*my_p = (actual_val&local_mask) | uart_val;

	ib_index++;
	if (ib_index >= INPUT_BUF_SZ) {
	  uart_putchar ( '>' );
	  uart_putchar ( 0xa );
	  goto end;
	}

      } /* if ((uart_byte=='>') || (uart_byte==0x0a) || (uart_byte==0x0d)) */

    } /* for (;;) */

    sleep ( 50 );

    asm ( "nop" );
    *leds_reg = leds & 0xff;
    asm ( "nop" );
    leds ^= mask;
    asm ( "nop" );

  }

  uart_putchar ( '!' );
  uart_putchar ( 0xa );

 end:
  uart_byte = 0;
  return;
}



int main () {
    struct lregs *hw = ( struct lregs * )( PREGS );
    volatile int* leds_reg = ( volatile int* ) LEDS_BASE_ADDR;
    unsigned int mask = 0xff;
    unsigned int leds = mask;
    uint32_t loop_cnt=0;
    volatile uint32_t* robot_reg = ( volatile int* ) ROBOT_BASE_ADDR;
    uint32_t robot_timer_val=0;
    uint32_t robot_timer_val_ms=0;
    int pwd_state;

    uint32_t my_val32;
    uint32_t mem_test_addr;
    uint32_t mem_test_data;
    uint32_t new_spi_slv_data;
    uint32_t new_spi_mst_data;


    i2c_test_data = 0;

    uart_init ( B115200 );

#if 1 /* FIXME : DEBUG */
    pwd_state = 0;
    for (;;) {
      asm ( "nop" );
      *leds_reg = leds & 0xff;
      asm ( "nop" );

      sleep ( 100 );

      asm ( "nop" );
      leds ^= mask;
      asm ( "nop" );

      unsigned int my_uartstatus1 = hw->uartstatus1;
      if ( my_uartstatus1 & UART_STATUS_DR ) {
	unsigned int my_uartdata1 = hw->uartdata1;
	uart_byte = my_uartdata1;
	switch (pwd_state) {
	case 0:
	  if (uart_byte=='g') pwd_state = 1; else pwd_state = 0;
	  break;
	case 1:
	  if (uart_byte=='o') pwd_state = 2; else pwd_state = 0;
	  break;
	case 2:
	  if (uart_byte=='l') pwd_state = 3; else pwd_state = 0;
	  break;
	case 3:
	  if (uart_byte=='d') pwd_state = 4; else pwd_state = 0;
	  break;
	case 4:
	  if (uart_byte=='o') pwd_state = 5; else pwd_state = 0;
	  break;
	}
      }

      if (pwd_state == 5) break;
    }
#endif

    uart_putchar ( 0xa );
    uart_putstring ( "Robot GOLDO Little - soft test SPI (21112016)" );
    uart_putchar ( 0xa );
    uart_putstring ( "Commandes :" );
    uart_putchar ( 0xa );
    uart_putstring ( "   @ : adresse de test AHB/APB" );
    uart_putchar ( 0xa );
    uart_putstring ( "   $ : data de test AHB/APB" );
    uart_putchar ( 0xa );
    uart_putstring ( "   R : test lecture 32b AHB/APB" );
    uart_putchar ( 0xa );
    uart_putstring ( "   W : test ecriture 32b AHB/APB" );
    uart_putchar ( 0xa );
    uart_putstring ( "   ! : charger nouveau soft" );
    uart_putchar ( 0xa );
    uart_putstring ( "   O : write SPI data to be sent to master" );
    uart_putchar ( 0xa );
    uart_putstring ( "<SPACE> : read received SPI data" );
    uart_putchar ( 0xa );
    uart_putstring ( "   % : robot reset" );
    uart_putchar ( 0xa );

    uart_putchar ( 0xa );
    loop_cnt=0;

    /* robot reset */
    robot_reg[R_ROBOT_RESET] = 1;
    robot_reg[R_ROBOT_RESET] = 0;


    for (;;) {

      asm ( "nop" );
      *leds_reg = leds & 0xff;
      asm ( "nop" );

      sleep ( 10 );

      unsigned int my_uartstatus1 = hw->uartstatus1;
      if ( my_uartstatus1 & UART_STATUS_DR ) {
	unsigned int my_uartdata1 = hw->uartdata1;

	uart_byte = my_uartdata1;


	if (uart_byte=='@') {
	  uart_putstring ( "@ : " );
	  edit_input_buf ();
	  mem_test_addr = convert_input_buf_to_hexint();
	  uart_putchar ( 0xa );
	}

	if (uart_byte=='$') {
	  uart_putstring ( "$ : " );
	  edit_input_buf ();
	  mem_test_data = convert_input_buf_to_hexint();
	  uart_putchar ( 0xa );
	}

	if (uart_byte=='R') {
	  my_val32 = read_test_32b((uint32_t *) mem_test_addr);
	  uart_putstring ( "@0x" );
	  uart_printhex ( mem_test_addr );
	  uart_putstring ( " : 0x" );
	  uart_printhex ( my_val32 );
	  uart_putchar ( 0xa );
	}

	if (uart_byte=='W') {
	  write_test_32b((uint32_t *) mem_test_addr, mem_test_data);
	  uart_putstring ( "0x" );
	  uart_printhex ( mem_test_data );
	  uart_putstring ( "=> @0x" );
	  uart_printhex ( mem_test_addr );
	  uart_putchar ( 0xa );
	}

	if ((uart_byte=='!')) { /* load new soft */
	  uart_putchar ( '!' );
	  uart_putchar ( 0xa );
	  asm ( "call 0x10000000" ); /* call load_bitstream */
	}

	if ((uart_byte=='%')) { /* robot reset */
	  uart_putstring ( "RESET" );
	  uart_putchar ( 0xa );
	  robot_reg[R_ROBOT_RESET] = 1;
	  robot_reg[R_ROBOT_RESET] = 0;
	}

	if ((uart_byte=='O')) {
	  uart_putstring ( "new PSI slv data : " );
	  edit_input_buf ();
	  new_spi_slv_data = convert_input_buf_to_hexint();
	  uart_putchar ( 0xa );

	  robot_reg[0xd8] = new_spi_slv_data;

	  uart_putstring ( " >0x" );
	  uart_printhex ( new_spi_slv_data );
	  uart_putchar ( 0xa );
	}


	if ((uart_byte==' ')) {
	  uart_putstring ( "new SPI mst data : " );

	  new_spi_mst_data = robot_reg[0xd9];

	  uart_putstring ( " >0x" );
	  uart_printhex ( new_spi_mst_data );
	  uart_putchar ( 0xa );
	}
      }

      robot_timer_val = robot_reg[R_ROBOT_TIMER];
      robot_timer_val_ms = robot_timer_val/1000;


      asm ( "nop" );
      leds ^= mask;
      asm ( "nop" );

      loop_cnt++;
    }

    return 0;
}
