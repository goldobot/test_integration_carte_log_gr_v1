#include <stdlib.h>
#include <stdio.h>
#include <math.h>

long long int my_val_int64;
double my_val_double;
float my_val_float;

int main (int argc, char **argv)
{
  if (argc<2) {
    printf (" Usage : %s <val_float>\n", argv[0]);
    return -1;
  }

  printf (" sizeof (my_val_int64) = %lu\n", sizeof (my_val_int64));
  printf (" sizeof (my_val_double) = %lu\n", sizeof (my_val_double));
  printf (" sizeof (my_val_float) = %lu\n", sizeof (my_val_float));

  my_val_double = atof (argv[1]);
  printf (" my_val_double      = % .20f\n", my_val_double);
  printf (" sin(my_val_double) = % .20f\n", sin(my_val_double));

  return 0;
}
