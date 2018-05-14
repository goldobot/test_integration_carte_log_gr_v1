#ifndef __TIMER_H
#define __TIMER_H

#include "types.h"

extern volatile uint32_t timer_counter;

struct timer_config_t {
    uint32_t prescaler;
    uint32_t counter;
};

/* Init value for a 1 kHz counter */
void timer_set_config ( struct timer_config_t *cfg );

/* Enable timer 1 */
void timer_enable ();

/* Disable timer 1 */
void timer_disable ();

#endif
