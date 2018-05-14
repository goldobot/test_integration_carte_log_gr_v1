timer1_handler:
	set	timer_counter, %l3
	ld	[%l3], %l4
	inc	%l4
	st	%l4, [%l3]
	set	PREGS, %l3
	set	(1 << IRQ_TIMER1), %l4
	st	%l4, [%l3 + ICLEAR]
	jmp	%l1
	rett	%l2

	.data
timer_counter:
	.long	0
