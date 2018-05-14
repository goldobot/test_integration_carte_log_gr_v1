import numpy as np
from matplotlib.lines import Line2D
from matplotlib.text import Text
from matplotlib.artist import Artist
from matplotlib.mlab import dist_point_to_segment
import matplotlib.pyplot as plt
import time
import socket
import re
import threading


# cmdline to execute script : python -i robot_ihm.py

def ihm_draw_callback(event):
  ax.draw_artist(robot_body_line)
  ax.draw_artist(robot_arrow_line)
  ax.draw_artist(board_limit_line)
  my_canvas.blit(ax.bbox)


def robot_change_state(xc=0.0, yc=0.0, theta=0.5*np.pi):
  robot_xc=xc
  robot_yc=yc
  robot_theta=theta
  robot_arrow_x=robot_xc+robot_r*np.cos(robot_theta)
  robot_arrow_y=robot_yc+robot_r*np.sin(robot_theta)
  robot_left_x=robot_xc-robot_r*np.sin(robot_theta)
  robot_left_y=robot_yc+robot_r*np.cos(robot_theta)
  robot_right_x=robot_xc+robot_r*np.sin(robot_theta)
  robot_right_y=robot_yc-robot_r*np.cos(robot_theta)
  new_body_data=(np.array([robot_left_x, robot_right_x]), np.array([robot_left_y, robot_right_y]))
  robot_body_line.set_data(new_body_data)
  new_arrow_data=(np.array([robot_xc, robot_arrow_x]), np.array([robot_yc, robot_arrow_y]))
  robot_arrow_line.set_data(new_arrow_data)
  robot_pos_text.set_text ('(%f %f %f*pi)'%(robot_xc, robot_yc, robot_theta/np.pi))


def sock_listener():
  global stop_sock_listener
  global robot_state_changed
  my_sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
  my_sock.bind(("0.0.0.0",4242))
  my_str = "begin"
#  while ((my_str != "quit") and (stop_sock_listener==0)):
  while (my_str != "quit"):
    my_str=my_sock.recv(64)
    m=re.match('<(.+)[,\s](.+)[,\s](.+)>', my_str)
    if m!=None:
      xc=float(m.group(1))
      yc=float(m.group(2))
      theta=float(m.group(3))
      robot_change_state(xc, yc, theta)
#      my_canvas.draw()
      robot_state_changed=1
#  print ("my_str=" + my_str)
  print ("Exit listener")


def canvas_timer_callback(arg):
  global robot_state_changed
#  print ('Pingo')
  if (robot_state_changed==1):
    robot_state_changed=0
    my_canvas.draw()


#global robot_state_changed
#global stop_sock_listener

robot_state_changed=0
stop_sock_listener=0

robot_r=0.1
robot_xc=0.0
robot_yc=0.1
robot_theta=0.5*np.pi

robot_body_x=np.array([robot_xc-0.1, robot_xc+0.1])
robot_body_y=np.array([robot_yc, robot_yc])
robot_body_line = Line2D(robot_body_x, robot_body_y, linestyle='-', linewidth=8, marker='o', markerfacecolor='r', animated=True)

robot_arrow_x=np.array([robot_xc, robot_xc])
robot_arrow_y=np.array([robot_yc, robot_yc+0.1])
robot_arrow_line = Line2D(robot_arrow_x, robot_arrow_y, linestyle='-', marker='o', markerfacecolor='r', animated=True)

# L(y)=1.38 W(x)=0.94
bvx0=-0.47
bvx1=0.47
bvx2=0.47
bvx3=-0.47

bvy0=0.0
bvy1=0.0
bvy2=1.38
bvy3=1.38

bxlim0=-0.8
bxlim1=0.8
bylim0=-0.1
bylim1=1.5

board_limit_x=np.array([bvx0, bvx1, bvx2, bvx3, bvx0])
board_limit_y=np.array([bvy0, bvy1, bvy2, bvy3, bvy0])
board_limit_line = Line2D(board_limit_x, board_limit_y, linestyle=':', linewidth=2, marker='o', markerfacecolor='b', animated=True)

fig, ax = plt.subplots()

robot_pos_text = ax.text (-0.7, -0.07, '(%f %f %f*pi)'%(robot_xc, robot_yc, robot_theta/np.pi))

ax.add_line(robot_body_line)
ax.add_line(robot_arrow_line)
ax.add_line(board_limit_line)

robot_change_state(robot_xc, robot_yc, robot_theta)

my_canvas = fig.canvas
my_canvas.mpl_connect('draw_event', ihm_draw_callback)
my_timer = my_canvas.new_timer(interval=20)
my_timer.add_callback(canvas_timer_callback, ())

my_timer.start()

ax.set_xlim((bxlim0,bxlim1))
ax.set_ylim((bylim0,bylim1))

my_thread = threading.Thread(target=sock_listener)
my_thread.start()

my_ctrl_sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)

plt.show(block=False)

#my_timer.stop()

#stop_sock_listener=1
#my_ctrl_sock.sendto("quit", ("127.0.0.1",4242))

#while True:
#  if (robot_state_changed==1):
#    my_canvas.draw()
#    robot_state_changed=0

# robot_change_state(xc=0.8, yc=0.4, theta=np.pi)
# my_canvas.draw()


