#ifndef __ROBOT_TYPES_H
#define __ROBOT_TYPES_H

#ifdef EMBEDDED

typedef int bool;
#define true	1
#define false	0
typedef unsigned int size_t;

#else

#include <string.h>

#endif

typedef unsigned char      uint8_t;
typedef unsigned short int uint16_t;
typedef unsigned int       uint32_t;

#ifndef NULL
#define NULL (( void* ) 0 )
#endif

#endif
