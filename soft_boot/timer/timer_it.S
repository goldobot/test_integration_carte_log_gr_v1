#include	"leon.h"

	.globl	timer1_handler
	
timer1_handler:
	!! l0 = psr
	!! l1 = PC
	!! l2 = nPC
	set	timer_counter, %l3
	ld	[%l3], %l4
	inc	%l4
	st	%l4, [%l3]
	set	PREGS, %l3
	set	(1 << IRQ_TIMER1), %l4
	st	%l4, [%l3 + ICLEAR]
	!
	mov	%l0, %psr	/* restore flags ! */
	jmp	%l1
	rett	%l2

