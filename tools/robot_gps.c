#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>

#include "i2c-dev.h"

#define ROBOT_I2C_CMD_GO          0x67000000
#define ROBOT_I2C_CMD_STOP        0x68000000
#define ROBOT_I2C_CMD_SET_TRAJ_D  0x44000000
#define ROBOT_I2C_CMD_SET_TRAJ_T  0x74000000
#define ROBOT_I2C_CMD_GET_STATE   0x3f000000

#define ROBOT_CMD_TYPE_NONE         0
#define ROBOT_CMD_TYPE_TRANSLATION  1
#define ROBOT_CMD_TYPE_ROTATION     2
#define ROBOT_CMD_TYPE_STATIC       3

#define ROBOT_I2C_CONF_TRANSLATION  (ROBOT_I2C_CMD_SET_TRAJ_T|ROBOT_CMD_TYPE_TRANSLATION)
#define ROBOT_I2C_CONF_ROTATION     (ROBOT_I2C_CMD_SET_TRAJ_T|ROBOT_CMD_TYPE_ROTATION)
#define ROBOT_I2C_CONF_STATIC       (ROBOT_I2C_CMD_SET_TRAJ_T|ROBOT_CMD_TYPE_STATIC)

#if 1 /* FIXME : DEBUG : demo ADS */
#define ROBOT_MM_PER_INC 0.078532
#define ROBOT_INC_PER_MM 12.734
#define ROBOT_RAD_PER_INC 0.000417
#define ROBOT_INC_PER_RAD 2397.51
#define ROBOT_DEG_PER_INC 0.023896
#define ROBOT_INC_PER_DEG 41.847
#else
#define ROBOT_MM_PER_INC 0.078532
#define ROBOT_INC_PER_MM 12.734
#define ROBOT_RAD_PER_INC 0.00041887902047863911
#define ROBOT_INC_PER_RAD 2387.32414637843
#define ROBOT_DEG_PER_INC 0.024
#define ROBOT_INC_PER_DEG 41.666666666666664
#endif

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

  usleep (20000);

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


#define CMD_LPORT 6660
#define CMD_LADDR "127.0.0.1:6660"

#define CMD_RPORT 7770
#define CMD_RADDR "127.0.0.1:7770"


#define IHM_PORT 4242
#define IHM_ADDR "192.168.0.76:4242"

#define MSG_BUF_LEN 64

char ihm_msg_buf[MSG_BUF_LEN];

char cmd_msg_buf[MSG_BUF_LEN];


double normalise_theta_rad (double _theta)
{
  double val;

  val=_theta;
  if (val<-M_PI) {
    while (val<-M_PI) val+=(2*M_PI);
  } else {
    while (val>=M_PI) val-=(2*M_PI);
  }

  return val;
}

double normalise_theta_deg (double _theta)
{
  double val;

  val=_theta;
  if (val<-180.0) {
    while (val<-180.0) val+=360.0;
  } else {
    while (val>=180.0) val-=360.0;
  }

  return val;
}

#define ROBOT_STATE_WAIT_START        0
#define ROBOT_STATE_IDDLE             1
#define ROBOT_STATE_MOVING_RUSH       2
#define ROBOT_STATE_MOVING            3
#define ROBOT_STATE_STOP_TLM_LEFT     4
#define ROBOT_STATE_STOP_TLM_RIGHT    5
#define ROBOT_STATE_STOP_TLM_BACK     6
#define ROBOT_STATE_STOP_BLOCKED      7
#define ROBOT_STATE_FUNNY_ACT         8
#define ROBOT_STATE_END_GAME          9
#define ROBOT_STATE_MOVING_RUSH_BACK  102

int robot_state = ROBOT_STATE_WAIT_START;
unsigned int robot_switches = 0x0e;
int robot_x_raw = 0;
double robot_x_meters = 0.0;
double robot_x = 0.0;
int robot_y_raw = 0;
double robot_y_meters = 0.0;
double robot_y = 0.0;
int robot_theta_raw = 0;
double robot_theta_rad = M_PI_2;
double robot_theta_deg = 90.0;
int robot_todo_dist_raw = 0;
int robot_match_timer_msec = 0;

#define STATE_BUF_SIZE 16
unsigned int state_buf[STATE_BUF_SIZE];

int robot_i2c_refresh_state()
{
  int i2c_result;
  unsigned int i2c_data;

  I2C_READ_WORD_BLOCKING();
  if (i2c_data!=0x3f) return 0;
  state_buf[0] = 0x3f;

  I2C_READ_WORD_BLOCKING();
  state_buf[1] = i2c_data;
  //timer_val = i2c_data;

  I2C_READ_WORD_BLOCKING();
  state_buf[2] = i2c_data;
  robot_x_raw = i2c_data;
  robot_x_meters = robot_x_raw*ROBOT_MM_PER_INC/1000.0;
  robot_x = robot_x_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  state_buf[3] = i2c_data;
  robot_y_raw = i2c_data;
  robot_y_meters = robot_y_raw*ROBOT_MM_PER_INC/1000.0;
  robot_y = robot_y_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  state_buf[4] = i2c_data;
  robot_theta_raw = i2c_data;
  robot_theta_rad = normalise_theta_rad(robot_theta_raw*ROBOT_RAD_PER_INC);
  robot_theta_deg = normalise_theta_deg(robot_theta_raw*ROBOT_DEG_PER_INC);

  I2C_READ_WORD_BLOCKING();
  state_buf[5] = i2c_data;
  robot_todo_dist_raw = i2c_data;

  I2C_READ_WORD_BLOCKING();
  state_buf[6] = i2c_data;
  robot_match_timer_msec = i2c_data;

  I2C_READ_WORD_BLOCKING();
  state_buf[7] = i2c_data;
  robot_state = i2c_data;

  I2C_READ_WORD_BLOCKING();
  state_buf[8] = i2c_data;
  robot_switches = i2c_data;

  return 1;
}



int main(int argc, char *argv[])
{
  int i;
  struct sockaddr_in ihm_raddr;
  struct sockaddr_in cmd_laddr;
  struct sockaddr_in cmd_raddr;
  unsigned int val0, val1, val2, val3;
  unsigned int port;

  int ihm_sock_fd = -1;
  int cmd_sock_fd = -1;
  int result = -1;
  int recv_len = -1;

  struct timeval my_timeout;
  fd_set my_readfds;
  fd_set my_writefds;
  fd_set my_exceptfds;

  for (i=0; i<MSG_BUF_LEN; i++) ihm_msg_buf[i]=' ';

  for (i=0; i<MSG_BUF_LEN; i++) cmd_msg_buf[i]=' ';

  if(i2c_init()!=0) {
    printf(" error : i2c_init() failed\n");
    return 1;
  }

  if (sscanf (IHM_ADDR, "%d.%d.%d.%d:%d", 
              &val3, &val2, &val1, &val0, &port) != 5) {
    printf(" error : cannot parse IHM_ADDR\n");
    goto error;
  }

  bzero(&ihm_raddr, sizeof(struct sockaddr_in));
  ihm_raddr.sin_family= AF_INET;
  ihm_raddr.sin_port= htons(port);
  ihm_raddr.sin_addr.s_addr= htonl((val3<<24) | (val2<<16) | (val1<<8) | (val0));

  ihm_sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (ihm_sock_fd<0) {
    printf(" error : cannot create ihm_sock_fd\n");
    goto error;
  }

  if (sscanf (CMD_RADDR, "%d.%d.%d.%d:%d", 
              &val3, &val2, &val1, &val0, &port) != 5) {
    printf(" error : cannot parse CMD_RADDR\n");
    goto error;
  }

  bzero(&cmd_raddr, sizeof(struct sockaddr_in));
  cmd_raddr.sin_family= AF_INET;
  cmd_raddr.sin_port= htons(port);
  cmd_raddr.sin_addr.s_addr= htonl((val3<<24) | (val2<<16) | (val1<<8) | (val0));

  if (sscanf (CMD_LADDR, "%d.%d.%d.%d:%d", 
              &val3, &val2, &val1, &val0, &port) != 5) {
    printf(" error : cannot parse CMD_LADDR\n");
    goto error;
  }

  bzero(&cmd_laddr, sizeof(struct sockaddr_in));
  cmd_laddr.sin_family= AF_INET;
  cmd_laddr.sin_port= htons(port);
  cmd_laddr.sin_addr.s_addr= htonl((val3<<24) | (val2<<16) | (val1<<8) | (val0));

  cmd_sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (cmd_sock_fd<0) {
    printf(" error : cannot create cmd_sock_fd\n");
    goto error;
  }

  result = bind (cmd_sock_fd, (struct sockaddr *) &cmd_laddr, sizeof(struct sockaddr_in));
  if (result<0) {
    printf(" error : cannot bind()\n");
    goto error;
  }

  while (1) {
    if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
      continue;
    }

    robot_i2c_refresh_state();

    sprintf (ihm_msg_buf, "<%f %f %f>", robot_x_meters, robot_y_meters, robot_theta_rad);

    sendto (ihm_sock_fd, ihm_msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &ihm_raddr, sizeof(struct sockaddr_in));

    my_timeout.tv_sec = 0;
    my_timeout.tv_usec = 50000;

    FD_ZERO (&my_readfds);
    FD_ZERO (&my_writefds);
    FD_ZERO (&my_exceptfds);

    FD_SET (cmd_sock_fd, &my_readfds);

    result = select (cmd_sock_fd+1, &my_readfds, &my_writefds, &my_exceptfds, &my_timeout);

    if (FD_ISSET(cmd_sock_fd, &my_readfds)) {
      recv_len = recv (cmd_sock_fd, cmd_msg_buf, MSG_BUF_LEN, 0);
      if (recv_len>0) {
	if (cmd_msg_buf[3]==0x3f/*ROBOT_I2C_CMD_GET_STATE*/) {
	  if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
	    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
	  } else {
	    robot_i2c_refresh_state();

	    result = sendto (cmd_sock_fd, (char *)state_buf, 
			     STATE_BUF_SIZE*sizeof(unsigned int), 0,
			     (struct sockaddr *) &cmd_raddr, 
			     sizeof(struct sockaddr_in));
	    if (result<0) {
	      printf(" error : sendto()\n");
	    }
	  }
	} else {
	  if (i2c_write_word  (cmd_msg_buf[0]+
			      (cmd_msg_buf[1]*0x100)+
			      (cmd_msg_buf[2]*0x10000)+
			      (cmd_msg_buf[3]*0x1000000))) {
	    printf(" error : i2c_write_word()\n");
	  }
	}
      } else {
	printf ("recv() error?\n");
      }
    } else if (result<0) {
      printf ("select() error?\n");
    } else {
      //printf (".\n");
    }

  }

  return 0;

 error:
  return -1;
}
