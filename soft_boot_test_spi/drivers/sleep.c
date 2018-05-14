#include "sleep.h"

void usleep ( unsigned int time_us )
{
  unsigned int robot_t, robot_t0, robot_t1;

  volatile unsigned int* robot_reg = ( volatile unsigned int* ) 0x80008000;

  robot_t0 = robot_reg[0x00];
  robot_t1 = robot_t0 + time_us;

  do {
    robot_t = robot_reg[0x00];
  } while (robot_t<robot_t1);
}
