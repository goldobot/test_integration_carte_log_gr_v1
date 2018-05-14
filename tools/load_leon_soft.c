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

int i2c_write_word (unsigned int data)
{
  i2c_buf[0] = 0x02;
  i2c_buf[1] = (data>>24) & 0xff;
  i2c_buf[2] = (data>>16) & 0xff;
  i2c_buf[3] = (data>>8) & 0xff;
  i2c_buf[4] = (data) & 0xff;
  if (write(i2c_dev_file, i2c_buf, 5) != 5) {
    printf("I2C Write failed\n");
    return -1;
  }

  return 0;
}


#define SOFT_HEX_BUF_SZ 0x40000
char soft_hex_buf[SOFT_HEX_BUF_SZ];

#define LEON_SOFT_WORD_SIZE 4096
unsigned int leon_soft_buf[LEON_SOFT_WORD_SIZE];

int main(int argc, char *argv[])
{
  int soft_file;
  char soft_file_name[80];
  int nchars;
  int i;
  char *pnext_token;
  int verbose=0;

  if(argc<2) {
    printf("Usage: %s <leon_soft.hex>\n", argv[0]);
    return 1;
  }
  if(argc==3) verbose=1;

  if(i2c_init()!=0) {
    return 1;
  }

  sprintf(soft_file_name, "%s", argv[1]);
  if ((soft_file = open(soft_file_name,O_RDWR)) < 0) {
    printf("Cannot open %s\n", soft_file_name);
    return 1;
  }

  if ((nchars=read(soft_file, soft_hex_buf, SOFT_HEX_BUF_SZ)) < 0) {
    printf("Cannot read %s\n", soft_file_name);
    return 1;
  } else {
    printf("Read %d chars\n", nchars);
  }
  soft_hex_buf[nchars] = 0;

  for (i=0; i<LEON_SOFT_WORD_SIZE; i++) {
    leon_soft_buf[i] = 0x01000000;
  }

  i=0;
  pnext_token = strtok(soft_hex_buf, "\n");
  while (pnext_token!=NULL) {
    leon_soft_buf[i] = strtoul(pnext_token, NULL, 16);
    i++;
    if (i>=LEON_SOFT_WORD_SIZE) break;
    pnext_token = strtok(NULL, "\n");
  }

  for (i=0; i<LEON_SOFT_WORD_SIZE; i++) {
    if (verbose)
      printf (" %6d: %.8x\n", i, leon_soft_buf[i]);
    if (i2c_write_word (leon_soft_buf[i])) break;
  }

  if(i2c_dev_file >= 0)
    close(i2c_dev_file);

  if(soft_file >= 0)
    close(soft_file);

  return 0;
}
