include	../Makefile.config

SRCS=newboot.S init.c trap.S
OBJS=$(SRCS:.c=.o)
OBJS+=$(SRCS:.S=.o)

all: $(OBJS)

clean:
	rm -f *.o *.exe *.dat

.depend: $(SRCS)
	$(CC) $(CFLAGS) -MM $(SRCS) > .depend

-include	.depend
