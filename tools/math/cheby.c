#include <stdlib.h>
#include <stdio.h>
#include <math.h>

unsigned int global_N;
int max_samples;

typedef double (*my_func_t) (double);


double cheby (int _n, double _x)
{
  switch (_n) {
  case 0:
    return 1;
  case 1:
    return _x;
  default:
    return 2.0*_x*cheby(_n-1,_x) - cheby(_n-2,_x);
  }

  return 0.0;
}

double _x_k (int _k)
{
  return M_PI*((double)_k-0.5)/global_N;
}

double _c_j (my_func_t _func, int _j)
{
  int k;
  double sigma = 0.0;
  double x_k;

  for (k=1; k<=global_N; k++) {
    x_k = _x_k(k);
    sigma += _func(cos(x_k)) * cos (x_k*_j);
  }

  return (2.0/global_N) * sigma;
}

double cheby_coeff[32];

void cheby_coeff_fill (my_func_t _func)
{
  int j;

  for (j=0; j<=global_N-1; j++)
    cheby_coeff[j] = _c_j (_func, j);
}

double cheby_approx (my_func_t _func, double _x)
{
  int k;
  double sigma = 0.0;

  for (k=0; k<=global_N-1; k++) {
    sigma += _c_j(_func, k) * cheby (k, _x);
  }

  return sigma - 0.5*_c_j(_func,0);
}

double clenshaw_approx (my_func_t _func, double _x)
{
  int k;
  double b_r, b_r1, b_r2, c_r;

  b_r1 = 0.0;
  b_r2 = 0.0;

  for (k=global_N-1; k>0; k--) {
    c_r = cheby_coeff[k];
    b_r = c_r + 2*_x*b_r1 - b_r2;
    b_r2 = b_r1;
    b_r1 = b_r;
  }

  return (_x*b_r1 - b_r2 + cheby_coeff[0]);
}


long long int my_val_int64;
double my_val_double;
float my_val_float;

int main (int argc, char **argv)
{
  int j;
  double my_cheby;
  double sigma;
  double approx_error;
  double max_approx_error;

  if (argc<4) {
    printf (" Usage : %s <global_N> <max_samples> <val_float>\n", argv[0]);
    return -1;
  }

#if 0
  printf (" sizeof (my_val_int64) = %lu\n", sizeof (my_val_int64));
  printf (" sizeof (my_val_double) = %lu\n", sizeof (my_val_double));
  printf (" sizeof (my_val_float) = %lu\n", sizeof (my_val_float));
#endif

#if 0
  printf (" M_PI               = % .20f\n", M_PI);
#endif

  global_N = atoi (argv[1]);
  printf (" global_N = %d\n", global_N);

  max_samples = atoi (argv[2]);
  printf (" max_samples = %d\n", max_samples);

  my_val_double = atof (argv[3]);
  printf (" my_val_double      = % .20f\n", my_val_double);
  printf (" sin(my_val_double) = % .20f\n", (double) sin(my_val_double));

#if 0
  my_cheby = cheby_approx (sin, my_val_double);
  printf (" cheby_approx (sin, my_val_double) = % .20f\n", my_cheby);

  printf (" approx_error = % .20f\n", fabs(sin(my_val_double)-my_cheby));
#endif

  cheby_coeff_fill (sin);
  for (j=0; j<=global_N-1; j++) {
    if ((j&1)==0) cheby_coeff[j] = 0;
  }
  my_cheby = clenshaw_approx (sin, my_val_double);
  printf (" clenshaw_approx (sin, my_val_double) = % .20f\n", my_cheby);

  printf (" approx_error = % .20f\n", fabs(sin(my_val_double)-my_cheby));

#if 0
  for (j=0; j<global_N; j++) {
    printf (" _c_j(sin,%d)        = % .20f\n", j, _c_j(sin,j));
  }
#endif

#if 1
  for (j=0; j<global_N; j++) {
    printf (" cheby_coeff[%d]        = % .20f\n", j, cheby_coeff[j]);
  }
#endif

  sigma = 0.0;
  max_approx_error = 0.0;
  for (j=0; j<max_samples; j++) {
    my_val_double = (double)j;
    my_val_double = my_val_double/max_samples;
    my_cheby = clenshaw_approx (sin, my_val_double);
    approx_error = fabs(sin(my_val_double)-my_cheby);
    if (max_approx_error<approx_error) max_approx_error=approx_error;
    sigma += approx_error;
  }
  sigma = sigma/max_samples;
  printf (" mean approx_error = % .20f\n", sigma);
  printf (" max_approx_error = % .20f\n", max_approx_error);
  printf (" max_approx_error(E) = % .20e\n", max_approx_error);

  return 0;
}
