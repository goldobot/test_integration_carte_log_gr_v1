#ifndef _NEON_H_
#define _NEON_H_

/* memory areas */

#define CRAM		0x40000000
#define SDRAM		0x60000000
#define IOAREA		0x20000000

#define RAMSIZE         65336			// 64ko
#define RAMEND          (CRAM + RAMSIZE)
#define STACK_BOTTOM    (CRAM + RAMSIZE - 16)   // stack bottom
#define start           CRAM


#endif
