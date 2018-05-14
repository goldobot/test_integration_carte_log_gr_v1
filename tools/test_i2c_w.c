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
  int write_bytes;

  int i;
  printf("test robot i2c slave write\n");

  if(argc-1<1) {
    printf("Usage: %s <32b_word_to_write>\n", argv[0]);
    return(1);
  }

  i2c_addr = 0x42;
  printf(" i2c_addr = 0x%x\n", i2c_addr);

  write_bytes = 4;
  printf(" write_bytes = %d\n", write_bytes);

  data = strtol(argv[1], NULL, 16);
  printf(" data = %x\n", data);

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

  buf[0] = 0x02;
  buf[1] = (data>>24) & 0xff;
  buf[2] = (data>>16) & 0xff;
  buf[3] = (data>>8) & 0xff;
  buf[4] = (data) & 0xff;
  if (write(file, buf, 5) != 5) {
    printf("I2C Write failed\n");
    return(1);
  }

  if(file >= 0)
    close(file);

  return 0;
}
