#include <stdio.h>
#include <math.h>

#define ROBOT_INC_05PI_ROT     9592
#define ROBOT_INC_05PI_ROT_M   9600
#define ROBOT_SIN_TABLE_SIZE   151

int sin_table[ROBOT_SIN_TABLE_SIZE];

int main (int argc, char **argv)
{
  int i,j,k;
  int sin_val, s0, s1;

  for (i=0; i<ROBOT_SIN_TABLE_SIZE; i++) {
    sin_table[i] = 0x10000 * sin (0.5*M_PI*i/(ROBOT_SIN_TABLE_SIZE-1));
    printf (" %d\n", sin_table[i]);
  }

#if 0
  for (i=0; i<ROBOT_INC_05PI_ROT_M; i++) {
    j=i>>6;
    k=i-(j<<6);
    s0=sin_table[j];
    s1=sin_table[j+1];
    sin_val = s0 + (((s1-s0)*k)>>6);
    if ((i&3)!=0) sin_val++;
    printf (" %d\n", sin_val);
  }
#endif

  return 0;
}
