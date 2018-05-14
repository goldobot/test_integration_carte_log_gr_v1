#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

#define FXP_MULT (0x0001000000000000LL)

int main (int argc, char **argv)
{
  char *my_q15_48_hex;
  double my_val_double, val_tmp;
  long long int my_val_q15_48;

  if (argc!=2) {
    printf (" Usage : %s <val_q15_48_hex>\n", argv[0]);
    return -1;
  }

  my_q15_48_hex = argv[1];
  sscanf(my_q15_48_hex, "%llx", &my_val_q15_48);
  //printf (" my_val_q15_48       = 0x%.16llxLL\n", my_val_q15_48);

  val_tmp = my_val_q15_48;
  my_val_double = val_tmp/FXP_MULT;
  //printf (" my_val_double      = % .20f\n", my_val_double);
  printf (" % .20f\n", my_val_double);

  return 0;
}
