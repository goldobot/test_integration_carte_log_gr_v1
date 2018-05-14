#include "leds.h"

//use 8 bits mask for LEDs control
void leds_set ( unsigned char leds ) {
	volatile int* leds_reg = ( volatile int* ) LEDS_BASE_ADDR;
	*leds_reg = ~( leds & 0xff );
}

//use 8 bits mask for LEDs control
unsigned char leds_get () {
	volatile int* leds_reg = ( volatile int* ) LEDS_BASE_ADDR;
	return ( ~( *leds_reg ) ) & 0xff;
}
