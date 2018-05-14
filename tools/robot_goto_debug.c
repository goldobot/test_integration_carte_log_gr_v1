#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include "i2c-dev.h"

#define ROBOT_I2C_CMD_GO          0x67000000
#define ROBOT_I2C_CMD_STOP        0x68000000
#define ROBOT_I2C_CMD_SET_TRAJ_D  0x44000000
#define ROBOT_I2C_CMD_SET_TRAJ_T  0x74000000
#define ROBOT_I2C_CMD_GET_GPS     0x3f000000

#define ROBOT_MM_PER_INC 0.078532
#define ROBOT_INC_PER_MM 12.734
#define ROBOT_RAD_PER_INC 0.000417
#define ROBOT_INC_PER_RAD 2397.51
#define ROBOT_DEG_PER_INC 0.023896
#define ROBOT_INC_PER_DEG 41.847

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


#define IHM_PORT 4242
#define IHM_ADDR "192.168.0.76:4242"

#define MSG_BUF_LEN 64

char msg_buf[16];

static void inettoa (struct sockaddr_in *addr, char *str)
{
  unsigned int val0, val1, val2, val3;
  unsigned int port;

  val0= addr->sin_addr.s_addr & 0x000000ff;
  val1= (addr->sin_addr.s_addr & 0x0000ffff) >> 8;
  val2= (addr->sin_addr.s_addr & 0x00ffffff) >> 16;
  val3= addr->sin_addr.s_addr >> 24;

  port = ntohs(addr->sin_port);

  sprintf(str, "%d.%d.%d.%d:%d", val0, val1, val2, val3, port);
}

#define I2C_READ_WORD_BLOCKING() \
  do {                                                                      \
    i2c_result=0;                                                           \
    while (i2c_result==0) {                                                 \
      i2c_result = i2c_read_word (&i2c_data);                               \
      if (i2c_result==0) {                                                  \
        usleep(200);                                                        \
      } else if (i2c_result<0) {                                            \
        printf(" error : i2c_read_word()\n");                               \
        exit(-1);                                                           \
      }                                                                     \
    }                                                                       \
  } while (0)

int robot_i2c_get_gps(double *prx, double *pry, double *prtheta, 
		      int is_mm, int is_deg)
{
  int i2c_result;
  unsigned int i2c_data;
  int rx_raw = 0;
  int ry_raw = 0;
  int rtheta_raw = 0;

  I2C_READ_WORD_BLOCKING();
  if (i2c_data!=0x33) return 0;

  I2C_READ_WORD_BLOCKING();
  //timer_val = i2c_data;

  I2C_READ_WORD_BLOCKING();
  rx_raw = i2c_data;
  if (is_mm==0) /* meters */
    *prx = rx_raw*ROBOT_MM_PER_INC/1000.0;
  else
    *prx = rx_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  ry_raw = i2c_data;
  if (is_mm==0) /* meters */
    *pry = ry_raw*ROBOT_MM_PER_INC/1000.0;
  else
    *pry = ry_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  rtheta_raw = i2c_data;
  if (is_deg==0)
    *prtheta = rtheta_raw*ROBOT_RAD_PER_INC;
  else
    *prtheta = rtheta_raw*ROBOT_DEG_PER_INC;

  return 1;
}



int main(int argc, char *argv[])
{
  int i;
  double rx = 0.0;
  double ry = 0.1;
  double rtheta_rad = M_PI_2;
  double rtheta_deg = 90.0;
  struct sockaddr_in laddr, raddr;
  unsigned int val0, val1, val2, val3;
  unsigned int port;
  int result;
  unsigned int i2c_data;
#if 1 /* FIXME : DEBUG */
  int debug_D, debug_t;
  unsigned int debug_i2c_cmd;
#endif

  int nx_raw = 0;
  double nx = 0.0;
  int ny_raw = 0;
  double ny = 0.1;
  int ntheta_raw = 0;
  double ntheta = 90.0;

  int my_sock_fd = -1;

  for (i=0; i<MSG_BUF_LEN; i++) msg_buf[i]=' ';

  if((argc!=1) && (argc!=4)) {
    printf("Usage: %s <X_mm> <Y_mm> <Theta_deg>\n", argv[0]);
    return 1;
  }

  if (argc==4) {
#if 1 /* FIXME : DEBUG */
    if (argv[1][0]=='d') {
      debug_D = atoi(argv[2]);
      debug_t = atoi(argv[3]);
    } else {
      nx = atof(argv[1]);
      ny = atof(argv[2]);
      ntheta = atof(argv[3]);
    }
#else
    nx = atof(argv[1]);
    ny = atof(argv[2]);
    ntheta = atof(argv[3]);
#endif
  }

  if(i2c_init()!=0) {
    printf(" error : i2c_init() failed\n");
    return 1;
  }

  if (i2c_write_word (ROBOT_I2C_CMD_GET_GPS)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_GPS)\n");
    return 1;
  }

  result = robot_i2c_get_gps(&rx, &ry, &rtheta_deg, 1, 1);
  if (result==0) {
    printf(" error : robot_i2c_get_gps()\n");
    return 1;
  }

  printf ("actual pos : <%f %f %f°>\n", rx, ry, rtheta_deg);

  if (argc==4) {
    /* FIXME : TODO : GOTO */
#if 1 /* FIXME : DEBUG */
    i2c_write_word (ROBOT_I2C_CMD_STOP);
    usleep (20000);
    debug_D += 0x800000;
    debug_i2c_cmd = (unsigned int) debug_D;
    debug_i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_D | (debug_i2c_cmd & 0x00ffffff);
    i2c_write_word (debug_i2c_cmd);
    usleep (20000);
    debug_i2c_cmd = (unsigned int) debug_t;
    debug_i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_T | (debug_i2c_cmd & 0x00ffffff);
    i2c_write_word (debug_i2c_cmd);
    usleep (20000);
    i2c_write_word (ROBOT_I2C_CMD_GO);
    usleep (1000000);
    printf(" 1\n");
    usleep (1000000);
    printf(" 2\n");
    usleep (1000000);
    printf(" 3\n");
    i2c_write_word (ROBOT_I2C_CMD_STOP);
    usleep (20000);
#endif
  }

#if 0 /* FIXME : TODO */
  bzero(&laddr, sizeof(struct sockaddr_in));
  laddr.sin_family= AF_INET;
  laddr.sin_port= htons(2500); /* FIXME : TODO : must be parametrizable */
  laddr.sin_addr.s_addr= htonl(INADDR_ANY);

  if (sscanf (IHM_ADDR, "%d.%d.%d.%d:%d", 
              &val3, &val2, &val1, &val0, &port) != 5) {
    printf(" error : cannot parse IHM_ADDR\n");
    goto error;
  }

  bzero(&raddr, sizeof(struct sockaddr_in));
  raddr.sin_family= AF_INET;
  raddr.sin_port= htons(port);
  raddr.sin_addr.s_addr= htonl((val3<<24) | (val2<<16) | (val1<<8) | (val0));

  my_sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (my_sock_fd<0) {
    printf(" error : cannot create my_sock_fd\n");
    goto error;
  }
#endif

#if 0 /* FIXME : TODO */
  while (1) {
    result = robot_i2c_get_gps(&rx, &ry, &rtheta_rad, 0, 0);
    if (result==0) continue;

    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta_rad);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    //usleep (20000);
  }
#endif

  return 0;

 error:
  return -1;
}
