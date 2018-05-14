#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include "i2c-dev.h"

#define I2C_DEV   "/dev/i2c-0"

unsigned char buf[256];
unsigned int data = 0;

int main(int argc, char *argv[])
{
  int file;
  char filename[20];

  int i2c_addr;
  int read_bytes;

  int i;
  int result;

  printf("test robot i2c slave read\n");

  i2c_addr = 0x42;
  printf(" i2c_addr = 0x%x\n", i2c_addr);

  read_bytes = 4;
  printf(" read_bytes = %d\n", read_bytes);

  sprintf(filename, I2C_DEV);
  if ((file = open(filename,O_RDWR)) < 0) {
    printf("ERRNO: %s\n",strerror(errno));
    exit(1);
  } else {
    printf("Opened %s\n", I2C_DEV);
  }

  if (ioctl(file, I2C_SLAVE, i2c_addr) < 0) {
    printf("ERRNO: %s\n",strerror(errno));
    exit(1);
  }

  buf[0] = 0x01;
  if (write(file, buf, 1) != 1) {
    printf("I2C Send reg_addr (0x01) failed\n");
    return(1);
  }

  if ((result=read(file, buf, read_bytes)) != read_bytes) {
    printf("I2C Read failed (%d)\n", result);
    return(1);
  }

  printf("buf: ");
  for(i=0; i<read_bytes; i++) {
    printf("%x ", buf[i]);
  }
  printf("\n");

  data = (buf[0]<<24) + (buf[1]<<16) + (buf[2]<<8) + (buf[3]);

  printf("Data: ");
  printf("%x ", data);
  printf("\n");

  if(file >= 0)
    close(file);

  return 0;
}
