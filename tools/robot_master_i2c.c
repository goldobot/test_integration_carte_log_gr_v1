#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include "i2c-dev.h"


#define I2C_DEV "/dev/i2c-0"
#define I2C_SLAVE_ADDR 0x42

unsigned char i2c_buf[256];

int i2c_dev_file;
char i2c_dev_name[20];

int i2c_init (void)
{
  printf(" i2c_addr = 0x%x\n", I2C_SLAVE_ADDR);

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
  printf(" %s w <apb_addr> <data>\n", prog_name);
  printf(" %s r <apb_addr>\n", prog_name);
}

int main(int argc, char *argv[])
{
  int i;
  int is_write=0;
  unsigned int data = 0x42424242;
  unsigned int apb_addr;
  int result;

  if(argc<3) {
    usage(argv[0]);
    return 1;
  }

  if (argv[1][0]=='w') {
    is_write=1;
    if(argc<4) {
      usage(argv[0]);
      return 1;
    }
    apb_addr = strtoul(argv[2], NULL, 16);
    data = strtoul(argv[3], NULL, 16);
  } else if (argv[1][0]=='r') {
    is_write=0;
    apb_addr = strtoul(argv[2], NULL, 16);
  } else {
    usage(argv[0]);
    return 1;
  }

  if(i2c_init()!=0) {
    return 1;
  }

  if (is_write==1) {
    master_i2c_write_word (apb_addr, data);
    printf(" @0x%.8x : W 0x%.8x \n", apb_addr, data);
  } else {
    master_i2c_read_word (apb_addr, &data);
    printf(" @0x%.8x : R 0x%.8x \n", apb_addr, data);
  }

  return 0;
}
