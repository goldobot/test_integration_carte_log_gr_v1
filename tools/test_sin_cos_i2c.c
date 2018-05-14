#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include "i2c-dev.h"
#include <math.h>


#define FXP_MULT (0x0001000000000000LL)

#define I2C_DEV "/dev/i2c-0"
#define I2C_SLAVE_ADDR 0x42

unsigned char i2c_buf[256];

int i2c_dev_file;
char i2c_dev_name[20];

int i2c_init (void)
{
  //printf(" i2c_addr = 0x%x\n", I2C_SLAVE_ADDR);

  sprintf(i2c_dev_name, I2C_DEV);
  if ((i2c_dev_file = open(i2c_dev_name,O_RDWR)) < 0) {
    printf("i2c_init() : Cannot open %s\n", I2C_DEV);
    return -1;
  }

  if (ioctl(i2c_dev_file, I2C_SLAVE, I2C_SLAVE_ADDR) < 0) {
    printf("i2c_init() : Cannot assign device addr (%x) %s\n",
	   I2C_SLAVE_ADDR, I2C_DEV);
    return -1;
  }

  return 0;
}

int master_i2c_read_word (unsigned int apb_addr, unsigned int *pdata)
{
  unsigned int data;
  int rbytes;

  i2c_buf[0] = 0x03;
  i2c_buf[1] = (apb_addr>>24) & 0xff;
  i2c_buf[2] = (apb_addr>>16) & 0xff;
  i2c_buf[3] = (apb_addr>>8) & 0xff;
  i2c_buf[4] = (apb_addr) & 0xff;
  if (write(i2c_dev_file, i2c_buf, 5) != 5) {
    printf("I2C Send apb_addr (0x03) failed\n");
    return -1;
  }

  i2c_buf[0] = 0x05;
  if (write(i2c_dev_file, i2c_buf, 1) != 1) {
    printf("I2C Send APB read command (0x05) failed\n");
    return -1;
  }

  rbytes = read(i2c_dev_file, i2c_buf, 4);
  if (rbytes<4) {
    printf("I2C APB read failed\n");
    return -1;
  }

  data= (i2c_buf[0]<<24) + (i2c_buf[1]<<16) + (i2c_buf[2]<<8) + (i2c_buf[3]);
  *pdata = data;

  return 4;
}

int master_i2c_write_word (unsigned int apb_addr, unsigned int data)
{
  i2c_buf[0] = 0x03;
  i2c_buf[1] = (apb_addr>>24) & 0xff;
  i2c_buf[2] = (apb_addr>>16) & 0xff;
  i2c_buf[3] = (apb_addr>>8) & 0xff;
  i2c_buf[4] = (apb_addr) & 0xff;
  if (write(i2c_dev_file, i2c_buf, 5) != 5) {
    printf("I2C Send apb_addr (0x03) failed\n");
    return -1;
  }

  i2c_buf[0] = 0x04;
  i2c_buf[1] = (data>>24) & 0xff;
  i2c_buf[2] = (data>>16) & 0xff;
  i2c_buf[3] = (data>>8) & 0xff;
  i2c_buf[4] = (data) & 0xff;
  if (write(i2c_dev_file, i2c_buf, 5) != 5) {
    printf("I2C APB write (0x04) failed\n");
    return -1;
  }

  return 0;
}

void usage(const char *prog_name)
{
  printf("Usage:\n");
  printf(" %s <angle_in_radians>\n", prog_name);
}

int main(int argc, char *argv[])
{
  int i;
  int is_write=0;
  unsigned int data = 0x42424242;
  unsigned int apb_addr;
  int result;
  double angle_double, val_tmp;
  double sin_double, cos_double;
  long long int angle_q15_48;
  unsigned int *pword;

  if(argc<2) {
    usage(argv[0]);
    return 1;
  }

  angle_double = atof (argv[1]);
  //printf (" angle_double      = % .20f\n", angle_double);

  val_tmp = angle_double*FXP_MULT;
  angle_q15_48 = val_tmp;

  pword = (unsigned int *) &angle_q15_48;
  //printf (" pword[0] = %.8x\n", pword[0]);
  //printf (" pword[1] = %.8x\n", pword[1]);

  if(i2c_init()!=0) {
    printf("Cannot init i2c\n");
    return 1;
  }

  master_i2c_write_word (0x800082e8, pword[1]);
  usleep (100);

  master_i2c_write_word (0x800082ec, pword[0]);
  usleep (100);

  master_i2c_write_word (0x800082e0, 0x00000001);
  usleep (100);

  master_i2c_read_word (0x800082e8, &(pword[1]));
  usleep (100);

  master_i2c_read_word (0x800082ec, &(pword[0]));
  usleep (100);

  val_tmp = angle_q15_48;
  sin_double = val_tmp/FXP_MULT;

  master_i2c_read_word (0x800082f0, &(pword[1]));
  usleep (100);

  master_i2c_read_word (0x800082f4, &(pword[0]));
  usleep (100);

  val_tmp = angle_q15_48;
  cos_double = val_tmp/FXP_MULT;

  printf (" sin : % .20f\n", sin_double);
  printf (" cos : % .20f\n", cos_double);

  return 0;
}
