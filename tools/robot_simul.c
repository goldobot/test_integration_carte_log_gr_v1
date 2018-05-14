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

int main(int argc, char *argv[])
{
  int i;
  double rx = 0.0;
  double ry = 0.1;
  double rtheta = M_PI_2;
  struct sockaddr_in laddr, raddr;
  unsigned int val0, val1, val2, val3;
  unsigned int port;

  int my_sock_fd = -1;

  for (i=0; i<MSG_BUF_LEN; i++) msg_buf[i]=' ';

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

  while (ry<1.2) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    ry+=0.005;
    usleep (20000);
  }

  while (rtheta<M_PI) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rtheta+=(M_PI/20);
    usleep (20000);
  }
  rtheta=M_PI;
  sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);
  sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	 (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

  while (rx>-0.2) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rx-=0.005;
    usleep (20000);
  }

  while (rtheta<3*M_PI_2) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rtheta+=(M_PI/20);
    usleep (20000);
  }
  rtheta=3*M_PI_2;
  sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);
  sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	 (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

  while (ry>0.2) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    ry-=0.005;
    usleep (20000);
  }

  while (rtheta<2*M_PI) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rtheta+=(M_PI/20);
    usleep (20000);
  }
  rtheta=0.0;
  sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);
  sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	 (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

  while (rx<0.0) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rx+=0.005;
    usleep (20000);
  }

  while (rtheta<M_PI_2) {
    sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);

    sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	   (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));

    rtheta+=(M_PI/20);
    usleep (20000);
  }
  rtheta=M_PI_2;
  sprintf (msg_buf, "<%f %f %f>", rx, ry, rtheta);
  sendto (my_sock_fd, msg_buf, MSG_BUF_LEN, 0, 
	 (struct sockaddr *) &raddr, sizeof(struct sockaddr_in));
  sleep (1);

  return 0;

 error:
  return -1;
}
