include	../Makefile.config

SRCS=
# SRCS=timer.c timer_it.S
OBJS=$(SRCS:.c=.o) $(SRCS:.S=.o)

all: $(OBJS)

clean:
	rm -f *.o *.exe *.dat *~

.depend: $(SRC)
	$(CC) $(CFLAGS) -MM $(SRC) > .depend

-include	.depend
