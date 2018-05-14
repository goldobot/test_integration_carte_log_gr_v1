#include "leon.h"

	.globl	_init_traps

	.globl	_hardreset

	.globl	timer1_handler
	.globl	uart1_handler
	
!2.8     Exceptions 
!
!        LEON adheres to the general SPARC trap model. The table below shows the implemented 
!        traps and their individual priority. 
!
!         Trap                                TT            Pri    Description 
!
!         reset                              0x00            1     Power-on reset 
!         write error                        0x2b            2     write buffer error 
!         instruction_access_error           0x01            3     Error during instruction fetch 
!         illegal_instruction                0x02            5     UNIMP or other un-implemented instruction 
!         privileged_instruction             0x03            4     Execution of privileged instruction in user mode 
!         fp_disabled                        0x04            6     FP instruction while FPU disabled 
!         cp_disabled                        0x24            6     CP instruction while Co-processor disabled 
!         watchpoint_detected                0x0B            7     Instruction or data watchpoint match 
!         window_overflow                    0x05            8     SAVE into invalid window 
!         window_underflow                   0x06            8     RESTORE into invalid window 
!         register_hadrware_error            0x20            9     register file EDAC error (LEON-FT only) 
!         mem_address_not_aligned            0x07           10     Memory access to un-aligned address 
!         fp_exception                       0x08           11     FPU exception 
!         cp_exception                       0x28           11     Co-processor exception 
!         data_access_exception              0x09           13     Access error during load or store instruction 
!         tag_overflow                       0x0A           14     Tagged arithmetic overflow 
!         divide_exception                   0x2A           15     Divide by zero 
!         interrupt_level_1                  0x11           31     Asynchronous interrupt 1 (AHB error)
!         interrupt_level_2                  0x12           30     Asynchronous interrupt 2 (UART 2)
!         interrupt_level_3                  0x13           29     Asynchronous interrupt 3 (UART 1)
!         interrupt_level_4                  0x14           28     Asynchronous interrupt 4 (Parallel I/O [0])
!         interrupt_level_5                  0x15           27     Asynchronous interrupt 5 (Parallel I/O [1])
!         interrupt_level_6                  0x16           26     Asynchronous interrupt 6 (Parallel I/O [2])
!         interrupt_level_7                  0x17           25     Asynchronous interrupt 7 (Parallel I/O [3])
!         interrupt_level_8                  0x18           24     Asynchronous interrupt 8 (Timer 1)
!         interrupt_level_9                  0x19           23     Asynchronous interrupt 9 (Timer 2)
!         interrupt_level_10                 0x1A           22     Asynchronous interrupt 10 
!         interrupt_level_11                 0x1B           21     Asynchronous interrupt 11 
!         interrupt_level_12                 0x1C           20     Asynchronous interrupt 12 
!         interrupt_level_13                 0x1D           19     Asynchronous interrupt 13 
!         interrupt_level_14                 0x1E           18     Asynchronous interrupt 14 
!         interrupt_level_15                 0x1F           17     Asynchronous interrupt 15 
!         trap_instruction                   0x80-0xFF      16     Software trap instruction (TA) 

#define	LEDS	0x800000D4
#define TEMPO	500000
#define END_OF_TABLE	-1
	
	/* trap_handler must be aligned on a 4096 boundary !! */
	/* by default, will do hardreset! */
trap_handler:
	!!
	mov	%tbr, %l3
	mov	%psr, %l0
	srl	%l3, TBR_TT_SHIFT, %l3
	and	%l3, TBR_TT_MASK, %l3
	!! l0 = psr
	!! l1 = PC
	!! l2 = nPC
	!! l3 = TT value (read from TBR)
	set	trap_table, %l4
.lookup:
	ld	[%l4], %l5	! read first field (min or END_OF_TABLE)
	cmp	%l5, END_OF_TABLE		! end of table?
	be	.not_found
	cmp	%l5, %l3
	bg,a	.lookup		! min > TT ?
	add	%l4, 12, %l4	! next entry when branch taken (annul bit)
	ld	[%l4 + 4], %l5
	cmp	%l5, %l3
	bl,a	.lookup		! max < TT ?
	add	%l4, 12, %l4	! next entry when branch taken (annul bit)
	ld	[%l4 + 8], %l5
	jmp	%l5		! jump to handler
	nop
.not_found:
	set	trap_info, %l4
	st	%l0, [%l4]
	st	%l1, [%l4+4]
	st	%l2, [%l4+4]
	st	%l3, [%l4+4]		
	#ifdef LEDS
	mov	0x1, %l6
.animate:
	set	LEDS, %l7
	st	%l6, [%l7]
	sll	%l6, 1, %l7
	srl	%l6, 3, %l6
	or	%l6, %l7, %l6
	and	%l6, 0xf, %l6
	set	TEMPO, %l7
.wait:
	subcc	%l7, 1, %l7
	bne	.wait
	nop
	ba	.animate
	nop
	#endif
	set	_hardreset, %g1
	jmp	%g1
	nop
	
_init_traps:
	set	trap_handler, %g1 	/* must be aligned on a 4096 boundary !! */
	or	%g1, 0x3, %g1		/* set Single Vector Trap mode (custom, undocumented) */
	mov	%g1, %tbr
	retl
	nop
	
	/* a SAVE instruction caused a trap */
window_overflow_handler:
	set	PREGS, %l3
	ld	[%l3 + LCONF], %l5
	srl	%l5, LCONF_NWINDOWS_SHIFT, %l5
	and	%l5, LCONF_NWINDOWS_MASK, %l5
	! l5 = NWINDOWS - 1
	/* rotate WIM one bit right, we have NWINDOWS windows */
	mov	%wim, %l3
	sll	%l3, %l5, %l4
	srl	%l3, 1, %l3
	or	%l3, %l4, %l3
	/* Compute (1<<NWINDOWS)-1 */
	mov	1, %l4
	inc	%l5
	sll	%l4, %l5, %l4
	dec	%l4
	/* Mask */
	and	%l3, %l4, %l3

	/* disable WIM traps */
	mov	%g0, %wim
	nop
	nop
	nop

	/* point to correct window */
	save

	/* dump registers to stack */
	std	%l0, [%sp +  0]
	std	%l2, [%sp +  8]
	std	%l4, [%sp + 16]
	std	%l6, [%sp + 24]
	std	%i0, [%sp + 32]
	std	%i2, [%sp + 40]
	std	%i4, [%sp + 48]
	std	%i6, [%sp + 56]

	/* back to where we should be */
	restore

	/* set new value of window */
	mov	%l3, %wim
	nop
	nop
	nop

	/* go home */
	mov	%l0, %psr	/* restore flags ! */
	jmp	%l1		/* jump to SAVE instruction that caused the trap */
	rett	%l2
	
	/* a RESTORE instruction caused a trap */
window_underflow_handler:
	set	PREGS, %l3
	ld	[%l3 + LCONF], %l5
	srl	%l5, LCONF_NWINDOWS_SHIFT, %l5
	and	%l5, LCONF_NWINDOWS_MASK, %l5
	! l5 = NWINDOWS - 1
	/* rotate WIM one bit LEFT, we have NWINDOWS windows */ 
	mov	%wim, %l3
	srl	%l3, %l5, %l4
	sll	%l3,1, %l3
	or 	%l3, %l4, %l3
	/* Compute (1<<NWINDOWS)-1 */
	mov	1, %l4
	inc	%l5
	sll	%l4, %l5, %l4
	dec	%l4
	/* Mask */
	and	%l3, %l4, %l3

	/* disable WIM traps */
	mov	%g0, %wim
	nop
	nop
	nop

	/* point to correct window */
	restore
	restore

	/* dump registers to stack */
	ldd	[%sp +  0], %l0
	ldd	[%sp +  8], %l2
	ldd	[%sp + 16], %l4
	ldd	[%sp + 24], %l6
	ldd	[%sp + 32], %i0
	ldd	[%sp + 40], %i2
	ldd	[%sp + 48], %i4
	ldd	[%sp + 56], %i6

	/* back to where we should be */
	save
	save

	/* set new value of window */
	mov	%l3, %wim
	nop
	nop
	nop

	/* go home */
	mov	%l0, %psr	/* restore flags ! */	
	jmp	%l1		/* jump to RESTORE instruction that caused the trap */
	rett	%l2
	
/* Asynchronous Interrupt Request */
/*
irq_generic_handler:
	! l3 = Trap Type
	sub	%l3, 0x11, %l3
	set	1, %l4
	sll	%l4, %l3, %l3	// 1 << irq
	set	irq_table, %l4
	ld	[%l4], %l5
	or	%l5, %l3, %l5
	st	%l5, [%l4]
	jmp	%l1
	rett	%l2
*/

#ifdef MODELSIM
unimplemented_halt_simulation:
	.word	0
	.word	0
#endif
	
	.section        ".rodata"
	.align 4
trap_table:
#ifdef MODELSIM
	.long	2, 2, unimplemented_halt_simulation 
#endif
	.long	5, 5, window_overflow_handler
	.long	6, 6, window_underflow_handler
/* FIXME : DEBUG */
/*	.long	0x13, 0x13, uart1_handler */
/*	.long	0x18, 0x18, timer1_handler */
/*	.long	0x11, 0x1f, irq_generic_handler */
	.long	END_OF_TABLE

	.section	".bss"
trap_info:
	.long	0, 0, 0, 0
	
/*	
	.data
irq_table:
	.long	0
*/
