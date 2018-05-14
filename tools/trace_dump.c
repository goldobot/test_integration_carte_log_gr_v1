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

int i2c_read_word (unsigned int *pdata)
{
  unsigned int data;
  int rbytes;

  i2c_buf[0] = 0x01;
  if (write(i2c_dev_file, i2c_buf, 1) != 1) {
    printf("I2C Send reg_addr (0x01) failed\n");
    return -1;
  }

  rbytes = read(i2c_dev_file, i2c_buf, 4);
  if (rbytes<0) {
#if 0 /* FIXME : TODO : manage errors */
    printf("I2C Read failed\n");
    return -1;
#else
    return 0;
#endif
  } else if (rbytes<4) {
    return 0;
  }

  data= (i2c_buf[0]<<24) + (i2c_buf[1]<<16) + (i2c_buf[2]<<8) + (i2c_buf[3]);
  *pdata = data;

  return 4;
}


int main(int argc, char *argv[])
{
  int i;
  int words_per_line;
  unsigned int data;
  int result;

  if(argc!=2) {
    printf("Usage: %s <words_per_line>\n", argv[0]);
    return 1;
  }

  if(i2c_init()!=0) {
    return 1;
  }

  words_per_line = strtol(argv[1], NULL, 10);
  printf(" words_per_line = %d\n", words_per_line);

  i=0;
  while (1) {
    result = i2c_read_word (&data);
    if (result==0) {
      usleep(200);
      continue;
    } else if (result<0) {
      break;
    }

    printf ("%11d ", data);
    i++;
    if ((i%words_per_line)==0)
      printf ("\n");
  }

  return 0;
}
