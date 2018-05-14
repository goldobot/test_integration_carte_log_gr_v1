#include "leon.h"
#include "timer.h"

#include "config.h"

/* ! Set Timer 1 Frequency to 1 kHz  */
/* set	PREGS, %l3 */
/* set	(100-1), %l4	/\* !! not bigger than 2^9 = 512 !! *\/ */
/* st	%l4, [%l3 + SCNT] */
/* st	%l4, [%l3 + SRLD] */
/* set	(((CPU_FREQUENCY / 100) / 1000)-1), %l4 */
/* st	%l4, [%l3 + TCNT0] */
/* st	%l4, [%l3 + TRLD0] */
/* set	TIMER_LD|TIMER_RL|TIMER_EN, %l4 */
/* st	%l4, [%l3 + TCTRL0] */
/* set	(1 << IRQ_TIMER1), %l4 */
/* st	%l4, [%l3 + IMASK] */
/* ! */

volatile uint32_t timer_counter;

#define PRESCALER 100
#define TIMER_1KHZ ((( CPU_FREQUENCY / PRESCALER ) / 1000 ) -1 )

static struct timer_config_t timer_config = {
    PRESCALER - 1,
    TIMER_1KHZ
};

void timer_set_config ( struct timer_config_t *cfg ) {
    timer_config = *cfg;
}

void timer_enable () {
    struct lregs *hw = ( struct lregs * )( PREGS );
    hw->irqmask &= ~( 1<<IRQ_TIMER1 );

/* FIXME : DEBUG + */
    /* Contournement pour un bug d'init de la section .data */
    timer_config.prescaler = PRESCALER - 1;
    timer_config.counter = TIMER_1KHZ*500;
/* FIXME : DEBUG - */

    hw->scalercnt  = timer_config.prescaler;
    hw->scalerload = timer_config.prescaler;

    /* 1 kHz counter */
    hw->timercnt1  = timer_config.counter;
    hw->timerload1 = timer_config.counter;
    hw->timerctrl1 = TIMER_LD | TIMER_RL | TIMER_EN;

    timer_counter = 0;
    hw->irqmask |= 1<<IRQ_TIMER1;
}

void timer_disable () {
    struct lregs *hw = ( struct lregs * )( PREGS );
    hw->irqmask &= ~( 1<<IRQ_TIMER1 );
}
