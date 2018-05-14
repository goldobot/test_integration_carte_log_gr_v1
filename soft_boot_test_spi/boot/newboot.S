#include "leon.h"

	.global	_stack_top

	.global	_init_peripherals

	.global	_init_traps

	.globl	_hardreset

	.globl	_hardreset_real

	.globl	_hardreset_new_soft

	.globl	main

	.globl	big_bad_buf

#define BIG_BAD_BUF_OFFSET  0x60
	
	.text
_hardreset:
	flush
	nop
	set	_hardreset_real, %g1
	jmp	%g1
	nop

_hardreset_new_soft:
	flush
	set	0x00002000, %g1
	set	big_bad_buf, %g2
	add     %g2, BIG_BAD_BUF_OFFSET, %g2
	mov	%g0, %g3
	add     %g3, BIG_BAD_BUF_OFFSET, %g3
.load_soft_loop:
	ld      [%g2], %g5
	st      %g5, [%g3]
	add     %g2, 4, %g2
	add     %g3, 4, %g3
	subcc	%g1, 1, %g1
	bge	.load_soft_loop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

_hardreset_real:
	flush			;
	nop
	nop
	nop
#if 1 /* FIXME : DEBUG */
	set	0x800000d4, %g7
	set	0xffffffff, %g5
  st %g5, [%g7]
	nop
	nop
	nop
	set	0x40007ff0, %g7
	set	0x87654321, %g5
  st %g5, [%g7]
	nop
	nop
	nop
	set	0x40007ff0, %g7
	set	0x00000000, %g5
  ld [%g7], %g5
	nop
	nop
	nop
	set	0x800000d4, %g7
  st %g5, [%g7]
	nop
	nop
	nop
	set	0x00000108, %g7
  lda [%g7]0xF, %g5
	nop
	nop
	nop
#endif

	!!!!!!!!!!!!!!!!!!!!!!!!!
	!!! init Integer Unit !!!
	!!!!!!!!!!!!!!!!!!!!!!!!!
	
	!! init Processor State Register as follows:
	!!  disable coprocessor
	!!  disable FPU 
	!!  set Interrupt Level to 0
	!!  set/keep Supervisor Mode (ICC_S and ICC_PS)
	!!  disable Traps
	!!  current Window Pointer = 0
	set	PSR_ICC_S|PSR_ICC_PS, %g1 
	mov	%g1, %psr

	!! clear Window Invalid Mask Register
	mov	%g0, %wim
	nop
	nop
	nop
	
	!! clear Trap Base Register
	mov	%g0, %tbr

	!! clear Y
	mov	%g0, %y

	!! clear all registers of Integer Unit
	set	PREGS, %g7
	ld	[%g7 + LCONF], %g1
	srl	%g1, LCONF_NWINDOWS_SHIFT, %g1
	and	%g1, LCONF_NWINDOWS_MASK, %g1
	! g1 = NWINDOWS
	mov	%g0, %g2
	mov	%g0, %g3
	mov	%g0, %g4
	mov	%g0, %g5
	mov	%g0, %g6
.clear_window:
	mov	%g0, %l0
	mov	%g0, %l1
	mov	%g0, %l2
	mov	%g0, %l3
	mov	%g0, %l4
	mov	%g0, %l5
	mov	%g0, %l6
	mov	%g0, %l7
	mov	%g0, %o0
	mov	%g0, %o1
	mov	%g0, %o2
	mov	%g0, %o3
	mov	%g0, %o4
	mov	%g0, %o5
	mov	%g0, %o6
	mov	%g0, %o7
	subcc	%g1, 1, %g1
	bge	.clear_window
	save		! rotate window (delay slot)
	
	!! init stack and frame pointer
	set	_stack_top, %fp	! frame pointer
	mov	%fp, %sp	! stack pointer

	call	_init_peripherals
	nop

	call	_init_rom_data_bss
	nop

	call	_init_traps
	nop
	
	!! init Processor State Register as follows:
	!!  disable coprocessor
	!!  disable FPU 
	!!  set Interrupt Level to 0
	!!  set/keep Supervisor Mode (ICC_S and ICC_PS)
	!!  enable Traps
	!!  current Window Pointer = NWINDOWS-1
	set	PREGS, %g7
	ld	[%g7 + LCONF], %g2
	srl	%g2, LCONF_NWINDOWS_SHIFT, %g2
	and	%g2, LCONF_NWINDOWS_MASK, %g2
	
	and	%g2, PSR_ICC_CWP_MASK, %g2
	set	PSR_ICC_S|PSR_ICC_PS|PSR_ICC_ET, %g1
	or	%g1, %g2, %g1
	mov	%g1, %psr

	!! Window 1 is masked
	set	1, %g1
	mov	%g1, %wim	
	nop
	nop
	nop

	!! init stack and frame pointer (since CWP has changed)
	set	_stack_top, %fp	! frame pointer
	sub	%fp, 4*16 + 28 + 4, %sp	! stack pointer 

	!! jump to main loop
	set	main, %g1
	jmp	%g1
	nop
_end_of_prog:
	set	_end_of_prog, %g1
	jmp	%g1
	nop

