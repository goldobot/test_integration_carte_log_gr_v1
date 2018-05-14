#ifndef __ROBOT_LEDS_H
#define __ROBOT_LEDS_H

// Define LEDs base address
#define LEDS_BASE_ADDR 0x800000D4

/* Display the eight least significant bits of given char

   @param[in] leds = value to display */
void leds_set ( unsigned char leds );

/* Return the current state of leds (eight bits value)

   @return state of leds */
unsigned char leds_get ();

#endif
