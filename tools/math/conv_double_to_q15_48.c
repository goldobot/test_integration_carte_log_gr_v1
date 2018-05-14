#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#define FXP_MULT (0x0001000000000000LL)

int main (int argc, char **argv)
{
  double my_val_double, val_tmp;
  long long int my_val_q15_48;

  if (argc!=2) {
    printf (" Usage : %s <val_double_float>\n", argv[0]);
    return -1;
  }

  my_val_double = atof (argv[1]);
  //printf (" my_val_double      = % .20f\n", my_val_double);

  val_tmp = my_val_double*FXP_MULT;
  my_val_q15_48 = val_tmp;

  //printf (" my_val_q15_48       = 0x%.16llxLL\n", my_val_q15_48);
  printf ("%.16llx\n", my_val_q15_48);

  return 0;
}
