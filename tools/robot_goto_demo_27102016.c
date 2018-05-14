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

#define FXP_MULT (0x0001000000000000LL)

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

#if 1 /* FIXME : DEBUG : demo Electrolab 27102016 */
#define ROBOT_MM_PER_INC 0.07825720866112483
#define ROBOT_INC_PER_MM 12.77837552742616
#define ROBOT_RAD_PER_INC 0.0004163369991440998
#define ROBOT_INC_PER_RAD 2398.343422435717
#define ROBOT_DEG_PER_INC 0.023854352906098688
#define ROBOT_INC_PER_DEG 41.921070084627466
#endif

#define ROBOT_USEC_PER_INC 3000


#define CMD_RPORT 6660
#define CMD_RADDR "127.0.0.1:6660"

#define CMD_LPORT 7770
#define CMD_LADDR "127.0.0.1:7770"

int cmd_sock_fd = -1;

struct sockaddr_in cmd_laddr, cmd_raddr;


#define MSG_BUF_LEN 64

char cmd_msg_buf[16];



#if 1 /* FIXME : DEBUG : DEMO Elab */
#define I2C_DEV "/dev/i2c-0"
#define I2C_SLAVE_ADDR 0x42


unsigned char i2c_buf[256];

int i2c_dev_file;
char i2c_dev_name[20];
#endif

#if 1 /* FIXME : DEBUG : DEMO Elab */
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
#endif

#if 0 /* FIXME : DEBUG : DEMO Elab */
static unsigned int i2c_fake_data;
#endif

int i2c_write_word (unsigned int data)
{
#if 1 /* FIXME : DEBUG : DEMO Elab */
  i2c_buf[0] = 0x02;
  i2c_buf[1] = (data>>24) & 0xff;
  i2c_buf[2] = (data>>16) & 0xff;
  i2c_buf[3] = (data>>8) & 0xff;
  i2c_buf[4] = (data) & 0xff;
  if (write(i2c_dev_file, i2c_buf, 5) != 5) {
    printf("I2C Write failed\n");
    return -1;
  }
#else
  i2c_fake_data = data;

  sendto (cmd_sock_fd, &i2c_fake_data, 4, 0, 
    (struct sockaddr *) &cmd_raddr, sizeof(struct sockaddr_in));
#endif

  usleep (20000);

  return 0;
}

#if 1 /* FIXME : DEBUG : DEMO Elab */
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
#endif

#if 1 /* FIXME : DEBUG : DEMO Elab */
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
#endif


int sock_init (void)
{
  int i;
  unsigned int val0, val1, val2, val3;
  unsigned int port;
  int result;

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

  return 0;

 error:
  return -1;
}



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

/* NEW GPS ++ */
long long int new_gps_robot_theta=0;
long long int new_gps_robot_x=0;
long long int new_gps_robot_y=0;
double new_gps_robot_x_double = 0.0;
double new_gps_robot_y_double = 0.0;
double new_gps_robot_theta_deg = 0.0;
double new_gps_robot_theta_rad = 0.0;
/* NEW GPS -- */

#define STATE_BUF_SIZE 16
unsigned int state_buf[STATE_BUF_SIZE];

int robot_refresh_state()
{
  int i2c_result;
  unsigned int i2c_data;

#if 1 /* FIXME : DEBUG : DEMO Elab */
  I2C_READ_WORD_BLOCKING();
  if (i2c_data!=0x3f) return 0;

  I2C_READ_WORD_BLOCKING();
  //timer_val = i2c_data;

  I2C_READ_WORD_BLOCKING();
  robot_x_raw = i2c_data;
  robot_x_meters = robot_x_raw*ROBOT_MM_PER_INC/1000.0;
  robot_x = robot_x_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  robot_y_raw = i2c_data;
  robot_y_meters = robot_y_raw*ROBOT_MM_PER_INC/1000.0;
  robot_y = robot_y_raw*ROBOT_MM_PER_INC;

  I2C_READ_WORD_BLOCKING();
  robot_theta_raw = i2c_data;
  robot_theta_rad = normalise_theta_rad(robot_theta_raw*ROBOT_RAD_PER_INC);
  robot_theta_deg = normalise_theta_deg(robot_theta_raw*ROBOT_DEG_PER_INC);

  I2C_READ_WORD_BLOCKING();
  robot_todo_dist_raw = i2c_data;

  I2C_READ_WORD_BLOCKING();
  robot_match_timer_msec = i2c_data;

  I2C_READ_WORD_BLOCKING();
  robot_state = i2c_data;

  I2C_READ_WORD_BLOCKING();
  robot_switches = i2c_data;

  {
    /* NEW GPS */
    unsigned int *pword;
    double val_tmp;

    pword = (unsigned int *)&new_gps_robot_x;
    I2C_READ_WORD_BLOCKING();
    pword++;
    *pword = i2c_data;
    pword--;
    I2C_READ_WORD_BLOCKING();
    *pword = i2c_data;

    pword = (unsigned int *)&new_gps_robot_y;
    I2C_READ_WORD_BLOCKING();
    pword++;
    *pword = i2c_data;
    pword--;
    I2C_READ_WORD_BLOCKING();
    *pword = i2c_data;

    pword = (unsigned int *)&new_gps_robot_theta;
    I2C_READ_WORD_BLOCKING();
    pword++;
    *pword = i2c_data;
    pword--;
    I2C_READ_WORD_BLOCKING();
    *pword = i2c_data;

    val_tmp = new_gps_robot_x;
    new_gps_robot_x_double = val_tmp/FXP_MULT;

    val_tmp = new_gps_robot_y;
    new_gps_robot_y_double = val_tmp/FXP_MULT;

    val_tmp = new_gps_robot_theta;
    val_tmp = val_tmp/FXP_MULT;
    new_gps_robot_theta_rad = normalise_theta_rad(val_tmp);
    val_tmp = 180.0*val_tmp/M_PI;
    new_gps_robot_theta_deg = normalise_theta_deg(val_tmp);

    robot_x = new_gps_robot_x_double;
    robot_x_meters = robot_x/1000.0;

    robot_y = new_gps_robot_y_double;
    robot_y_meters = robot_y/1000.0;

    robot_theta_rad = new_gps_robot_theta_rad;
    robot_theta_deg = new_gps_robot_theta_deg;
  }
#else
  int recv_len = -1;

  recv_len = recv (cmd_sock_fd, (char *)state_buf, 
		   STATE_BUF_SIZE*sizeof(unsigned int), 0);
  if (recv_len==STATE_BUF_SIZE*sizeof(unsigned int)) {
    i2c_data = state_buf[0];
    if (i2c_data!=0x3f) return 0;

    i2c_data = state_buf[1];
    //timer_val = i2c_data;

    i2c_data = state_buf[2];
    robot_x_raw = i2c_data;
    robot_x_meters = robot_x_raw*ROBOT_MM_PER_INC/1000.0;
    robot_x = robot_x_raw*ROBOT_MM_PER_INC;

    i2c_data = state_buf[3];
    robot_y_raw = i2c_data;
    robot_y_meters = robot_y_raw*ROBOT_MM_PER_INC/1000.0;
    robot_y = robot_y_raw*ROBOT_MM_PER_INC;

    i2c_data = state_buf[4];
    robot_theta_raw = i2c_data;
    robot_theta_rad = normalise_theta_rad(robot_theta_raw*ROBOT_RAD_PER_INC);
    robot_theta_deg = normalise_theta_deg(robot_theta_raw*ROBOT_DEG_PER_INC);

    i2c_data = state_buf[5];
    robot_todo_dist_raw = i2c_data;

    i2c_data = state_buf[6];
    robot_match_timer_msec = i2c_data;

    i2c_data = state_buf[7];
    robot_state = i2c_data;

    i2c_data = state_buf[8];
    robot_switches = i2c_data;
  } else {
    printf ("recv() error?\n");
  }
#endif

  return 1;
}

void wait_for_trans_end (double fx, double fy)
{
  int result;
  int i;
  double Dx = 0.0;
  double Dy = 0.0;
  double Dr = 0.0;

  for (i=0; i<100; i++) {
    usleep (100000);

    if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
      continue;
    }

    result = robot_refresh_state();
    if (result==0) {
      printf(" error : robot_refresh_state()\n");
      continue;
    }

    Dx = fx - robot_x;
    Dy = fy - robot_y;
    Dr = sqrt (Dx*Dx + Dy*Dy);

    if (robot_todo_dist_raw<50) break;
  }

  if (i==100) printf(" wait_for_trans_end() : timeout!\n");

  printf(" Final pos error : <%f,%f> (%f)\n", Dx, Dy, Dr);

  usleep (500000);
}

void wait_for_rot_end (double ftheta_deg)
{
  int result;
  int i;

  for (i=0; i<100; i++) {
    usleep (100000);

    if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
      continue;
    }

    result = robot_refresh_state();
    if (result==0) {
      printf(" error : robot_refresh_state()\n");
      continue;
    }

    if (robot_todo_dist_raw<100 /*50*/) break;
  }

  if (i==100) printf(" wait_for_rot_end() : timeout!\n");

  printf(" Final rot error : %f°\n", ftheta_deg-robot_theta_deg);

  usleep (500000);
}

void debug_traj (int dbg_t, int dbg_D)
{
  int result;
  int i;
  unsigned int i2c_cmd;
  int i2c_cmd_data_s;

  switch (dbg_t) {
  case 1:
    if (i2c_write_word (ROBOT_I2C_CONF_TRANSLATION)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_TRANSLATION)\n");
      exit (-1);
    }
    break;
  case 2:
    if (i2c_write_word (ROBOT_I2C_CONF_ROTATION)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_ROTATION)\n");
      exit (-1);
    }
    break;
  case 3:
    if (i2c_write_word (ROBOT_I2C_CONF_STATIC)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_STATIC)\n");
      exit (-1);
    }
  }

  i2c_cmd_data_s = dbg_D + 0x800000;
  i2c_cmd = (unsigned int) i2c_cmd_data_s;
  i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_D | (i2c_cmd & 0x00ffffff);
  if (i2c_write_word (i2c_cmd)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_SET_TRAJ_D)\n");
    exit (-1);
  }

  if (i2c_write_word (ROBOT_I2C_CMD_GO)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GO)\n");
    exit (-1);
  }

  for (i=0; i<100; i++) {
    usleep (100000);

    if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
      continue;
    }

    result = robot_refresh_state();
    if (result==0) {
      printf(" error : robot_refresh_state()\n");
      continue;
    }

    if (robot_todo_dist_raw<50) break;
  }

  if (i==100) printf(" debug_traj() : timeout!\n");

  usleep (500000);

  if (i2c_write_word (ROBOT_I2C_CMD_STOP)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_STOP)\n");
    exit (-1);
  }

}

void usage (char *prog_name)
{
  printf("Usage: %s\n", prog_name);
  printf("       %s d <debug_t> <debug_D>\n", prog_name);
  printf("       %s <X_mm> <Y_mm> [<Theta_deg>]\n", prog_name);
}

int main(int argc, char *argv[])
{
  int i;
  int result;

  unsigned int i2c_cmd;
  int i2c_cmd_data_s;

#if 1 /* FIXME : DEBUG */
  int debug_D, debug_t;
  unsigned int debug_i2c_cmd;
#endif

  int nx_raw = 0;
  double nx = 0.0;
  int ny_raw = 0;
  double ny = 0.1;
  int ntheta_raw = 0;
  double ntheta_rad = 0.0;
  double ntheta_deg = 90.0;

  double Dx = 0.0;
  double Dy = 0.0;
  double Dr = 0.0;
  double Dr_raw = 0.0;
  double Otheta_raw = 0.0;
  double Otheta_deg = 0.0;
  double Otheta_rad = 0.0;
  double Dtheta_raw = 0.0;
  double Dtheta_deg = 0.0;
  double Dtheta_rad = 0.0;


  int my_sock_fd = -1;

  int do_debug = 0;

  for (i=0; i<MSG_BUF_LEN; i++) cmd_msg_buf[i]=' ';

  if((argc!=1) && (argc!=3) && (argc!=4)) {
    usage (argv[0]);
    return 1;
  }

  if (argc>=3) {
    if (argv[1][0]=='d') {
      if (argc!=4) {
	usage (argv[0]);
	return 1;
      }
      debug_t = atoi(argv[2]);
      debug_D = atoi(argv[3]);

      printf (" debug_t = %d\n", debug_t);
      printf (" debug_D = %d\n", debug_D);

      do_debug = 1;
    } else {
      nx = atof(argv[1]);
      ny = atof(argv[2]);
      if (argc==4)
	ntheta_deg = normalise_theta_deg(atof(argv[3]));
    }
  }

#if 1 /* FIXME : DEBUG : DEMO Elab */
  if(i2c_init()!=0) {
    printf(" error : i2c_init() failed\n");
    return 1;
  }
#else
  if(sock_init()!=0) {
    printf(" error : sock_init() failed\n");
    return 1;
  }
#endif

  if(do_debug) {
    debug_traj(debug_t, debug_D);
    return 0;
  }

  if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
    return 1;
  }

  result = robot_refresh_state();
  if (result==0) {
    printf(" error : robot_refresh_state()\n");
    return 1;
  }

  if (argc==1) {
    printf ("Actual position : <%f %f %f°>\n", robot_x, robot_y, robot_theta_deg);
    printf ("Robot state : %d\n", robot_state);
    printf ("Game timer : %d\n", robot_match_timer_msec);

    printf ("NEW GPS : <%f %f %f°>\n", 
	    new_gps_robot_x_double, 
	    new_gps_robot_y_double, 
	    new_gps_robot_theta_deg);
    return 0;
  }

  if (argc==3) {
    printf ("new pos (x,y) : <%f %f>\n", nx, ny);
  } else if (argc==4) {
    printf ("new pos (x,y,theta) : <%f %f %f°>\n", nx, ny, ntheta_deg);
  }

  if (argc>=3) {
    /* (1) Initial rotation *************************************************/
    Dx = nx - robot_x;
    Dy = ny - robot_y;
    if (abs(Dx)>0.000001) {
      Otheta_rad = atan (Dy/Dx);
      if (Dx<0) {
	if (Otheta_rad>0) Otheta_rad -= M_PI;
	else Otheta_rad += M_PI;
      }
    } else {
      if (Dy<0) Otheta_rad = -M_PI_2;
      else Otheta_rad = M_PI_2;
    }
    Otheta_raw = Otheta_rad*ROBOT_INC_PER_RAD;
    Otheta_deg = Otheta_raw*ROBOT_DEG_PER_INC;
    printf ("Need to change theta : %f°\n", Otheta_deg);

    Dtheta_rad = normalise_theta_rad(Otheta_rad - robot_theta_rad);
    Dtheta_raw = Dtheta_rad*ROBOT_INC_PER_RAD;
    Dtheta_deg = Dtheta_raw*ROBOT_DEG_PER_INC;
    printf ("Initial rotation : %f°\n", Dtheta_deg);

    if (i2c_write_word (ROBOT_I2C_CONF_ROTATION)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_ROTATION)\n");
      return 1;
    }

    i2c_cmd_data_s = Dtheta_raw + 0x800000;
    i2c_cmd = (unsigned int) i2c_cmd_data_s;
    i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_D | (i2c_cmd & 0x00ffffff);
    if (i2c_write_word (i2c_cmd)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_SET_TRAJ_D)\n");
      return 1;
    }

    if (i2c_write_word (ROBOT_I2C_CMD_GO)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GO)\n");
      return 1;
    }
    wait_for_rot_end (Otheta_deg);

    if (i2c_write_word (ROBOT_I2C_CMD_STOP)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_STOP)\n");
      return 1;
    }
    /************************************************************************/

    /* (2) Translation ******************************************************/
    Dr = sqrt (Dx*Dx + Dy*Dy);
    Dr_raw = Dr*ROBOT_INC_PER_MM;
    printf ("Translation : %f mm\n", Dr);

    if (i2c_write_word (ROBOT_I2C_CONF_TRANSLATION)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_TRANSLATION)\n");
      return 1;
    }

    i2c_cmd_data_s = Dr_raw + 0x800000;
    i2c_cmd = (unsigned int) i2c_cmd_data_s;
    i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_D | (i2c_cmd & 0x00ffffff);
    if (i2c_write_word (i2c_cmd)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_SET_TRAJ_D)\n");
      return 1;
    }

    if (i2c_write_word (ROBOT_I2C_CMD_GO)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GO)\n");
      return 1;
    }
    wait_for_trans_end (nx, ny);

    if (i2c_write_word (ROBOT_I2C_CMD_STOP)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_STOP)\n");
      return 1;
    }
    /************************************************************************/
  }

  if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
    return 1;
  }

  result = robot_refresh_state();
  if (result==0) {
    printf(" error : robot_refresh_state()\n");
    return 1;
  }

  printf ("After translation : <%f %f %f°>\n", robot_x, robot_y, robot_theta_deg);

  if (argc==4) {
    ntheta_raw = ntheta_deg*ROBOT_INC_PER_DEG;
    ntheta_rad = ntheta_raw*ROBOT_RAD_PER_INC;

    /* (3) Final rotation ***************************************************/
    printf ("Need to change theta : %f°\n", ntheta_deg);

    Dtheta_rad = normalise_theta_rad(ntheta_rad - robot_theta_rad);
    Dtheta_raw = Dtheta_rad*ROBOT_INC_PER_RAD;
    Dtheta_deg = Dtheta_raw*ROBOT_DEG_PER_INC;
    printf ("Final rotation : %f°\n", Dtheta_deg);

    if (i2c_write_word (ROBOT_I2C_CONF_ROTATION)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CONF_ROTATION)\n");
      return 1;
    }

    i2c_cmd_data_s = Dtheta_raw + 0x800000;
    i2c_cmd = (unsigned int) i2c_cmd_data_s;
    i2c_cmd = ROBOT_I2C_CMD_SET_TRAJ_D | (i2c_cmd & 0x00ffffff);
    if (i2c_write_word (i2c_cmd)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_SET_TRAJ_D)\n");
      return 1;
    }

    if (i2c_write_word (ROBOT_I2C_CMD_GO)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_GO)\n");
      return 1;
    }
    wait_for_rot_end (ntheta_deg);

    if (i2c_write_word (ROBOT_I2C_CMD_STOP)) {
      printf(" error : i2c_write_word(ROBOT_I2C_CMD_STOP)\n");
      return 1;
    }
    /************************************************************************/
  }

  if (i2c_write_word (ROBOT_I2C_CMD_GET_STATE)) {
    printf(" error : i2c_write_word(ROBOT_I2C_CMD_GET_STATE)\n");
    return 1;
  }

  result = robot_refresh_state();
  if (result==0) {
    printf(" error : robot_refresh_state()\n");
    return 1;
  }

  printf ("Final position : <%f %f %f°>\n", robot_x, robot_y, robot_theta_deg);

  return 0;

 error:
  return -1;
}
