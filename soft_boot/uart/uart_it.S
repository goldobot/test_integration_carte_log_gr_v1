#include "leon.h"

#define DATA_READY (1<<0)
#define OVERRUN (1<<4)
#define PAR_ERR (1<<5)
#define FRM_ERR (1<<6)

#define WR_IDX 256
#define RD_IDX 257

#define	LEDS	0x800000D4
	
	.globl uart1_handler

uart1_handler:
	!! l0 = psr
	!! l1 = PC
	!! l2 = nPC:
	set	PREGS, %l3
	ld	[%l3 + USTAT0], %l4	! read status
	btst	OVERRUN | PAR_ERR | FRM_ERR, %l4	! check for errors
	bne	.uart1_error
	ld	[%l3 + UDATA0], %l5	! read data (in delay slot)
	set	uart1_fifo, %l4
	ldub	[%l4 + WR_IDX], %l6	! write idx
	ldub	[%l4 + RD_IDX], %l7	! read idx
	dec	%l7
	and	%l7, 0xff, %l7
	cmp	%l6, %l7
	be	.uart1_full
	nop
	stb	%l5, [%l4 + %l6]
	inc	%l6
!	and	%l6, 0xff, %l6
	stb	%l6, [%l4 + WR_IDX]
	ba	.uart1_it_end
	nop
.uart1_full:
.uart1_error:
	bclr	OVERRUN | PAR_ERR | FRM_ERR, %l4
	st	%l4, [%l3 + USTAT0]
!	set	LEDS, %l5
!	st	%g0, [%l5]
.uart1_it_end:
	set	(1 << IRQ_UART1), %l4
	st	%l4, [%l3 + ICLEAR]
	!
	mov	%l0, %psr
	jmp	%l1
	rett	%l2
