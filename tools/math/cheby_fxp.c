#include <stdlib.h>
#include <stdio.h>
#include <math.h>

unsigned int global_N;
int max_samples;

typedef double (*my_func_t) (double);

#define FXP_MULT (0x0001000000000000LL)

double sin_scaled(double _x)
{
  return sin((M_PI/2.0)*_x);
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

double cheby_coeff_sin[32];
long long int cheby_coeff_sin_fxp[32];

void cheby_coeff_fill (my_func_t _func, double *_cheby_coeff)
{
  int j;

  for (j=0; j<=global_N-1; j++)
    _cheby_coeff[j] = _c_j (_func, j);
}

double clenshaw_approx (double *_cheby_coeff, double _x)
{
  int k;
  double b_r, b_r1, b_r2, c_r;

  b_r1 = 0.0;
  b_r2 = 0.0;

  for (k=global_N-1; k>0; k--) {
    c_r = _cheby_coeff[k];
    b_r = c_r + 2*_x*b_r1 - b_r2;
    b_r2 = b_r1;
    b_r1 = b_r;
  }

  return (_x*b_r1 - b_r2 + _cheby_coeff[0]);
}

long long int mult_q7_56 (long long int _a, long long int _b)
{
  __int128_t _a_128, _b_128, ret_128;

  _a_128 = _a;
  _b_128 = _b;
  ret_128 = _a_128*_b_128;
  ret_128 = ret_128 / FXP_MULT;
  return ret_128;
}

double clenshaw_approx_fxp (long long int *_cheby_coeff_fxp, double _x)
{
  int k;
  double _x_tmp, ret_tmp;
  long long int _x_ll, ret_ll;
  long long int b_r, b_r1, b_r2, c_r;

  _x_tmp = _x * FXP_MULT;
  _x_ll = _x_tmp;

  b_r1 = 0;
  b_r2 = 0;

  for (k=global_N-1; k>0; k--) {
    c_r = _cheby_coeff_fxp[k];
    b_r = c_r + 2*mult_q7_56(_x_ll,b_r1) - b_r2;
    b_r2 = b_r1;
    b_r1 = b_r;
  }

  ret_ll = (mult_q7_56(_x_ll,b_r1) - b_r2 + _cheby_coeff_fxp[0]);

  ret_tmp = ret_ll;
  ret_tmp = ret_tmp / FXP_MULT;
  return ret_tmp;
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
  double _x_tmp;
  double my_val_double_scaled;

  if (argc<4) {
    printf (" Usage : %s <global_N> <max_samples> <val_float>\n", argv[0]);
    return -1;
  }


  global_N = atoi (argv[1]);
  printf (" global_N = %d\n", global_N);

  max_samples = atoi (argv[2]);
  printf (" max_samples = %d\n", max_samples);

  my_val_double = atof (argv[3]);
  printf (" my_val_double      = % .20f\n", my_val_double);
  printf (" sin(my_val_double) = % .20f\n", (double) sin(my_val_double));

  my_val_double_scaled = my_val_double / (M_PI/2.0);

#if 0
  cheby_coeff_fill (sin, cheby_coeff_sin);
#else
  cheby_coeff_fill (sin_scaled, cheby_coeff_sin);
#endif
  for (j=0; j<=global_N-1; j++) {
    if ((j&1)==0) cheby_coeff_sin[j] = 0.0;
  }
  for (j=0; j<=global_N-1; j++) {
    _x_tmp = cheby_coeff_sin[j] * FXP_MULT;
    cheby_coeff_sin_fxp[j] = _x_tmp;
  }
#if 0
  my_cheby = clenshaw_approx (cheby_coeff_sin, my_val_double_scaled);
#else
  my_cheby = clenshaw_approx_fxp (cheby_coeff_sin_fxp, my_val_double_scaled);
#endif
  printf (" clenshaw_approx (sin, my_val_double) = % .20f\n", my_cheby);

  printf (" approx_error = % .20f\n", fabs(sin(my_val_double)-my_cheby));


#if 1
  for (j=0; j<global_N; j++) {
    printf (" cheby_coeff_sin[%d]      = % .20f\n", j, cheby_coeff_sin[j]);
  }
  for (j=0; j<global_N; j++) {
    printf (" cheby_coeff_sin_fxp[%d]  = 0x%.16llxLL\n", j, 
	    cheby_coeff_sin_fxp[j]);
  }
#endif


  sigma = 0.0;
  max_approx_error = 0.0;
  for (j=0; j<max_samples; j++) {
    my_val_double = (double)j;
    my_val_double = my_val_double/max_samples;
#if 0
    my_cheby = clenshaw_approx (cheby_coeff_sin, my_val_double);
#else
    my_cheby = clenshaw_approx_fxp (cheby_coeff_sin_fxp, my_val_double);
#endif
    approx_error = fabs(sin_scaled(my_val_double)-my_cheby);
    if (max_approx_error<approx_error) max_approx_error=approx_error;
    sigma += approx_error;
  }
  sigma = sigma/max_samples;
  printf (" mean approx_error = % .20f\n", sigma);
  printf (" max_approx_error = % .20f\n", max_approx_error);
  printf (" max_approx_error(E) = % .20e\n", max_approx_error);

  return 0;
}
