#include <stdio.h>

int main (int argc, char **argv)
{
  int i;

  for (i=0; i<4095; i++) printf (" %6d : \n", i);

  return 0;
}
