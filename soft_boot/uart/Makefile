include	../Makefile.config

# SRCS=uart.c uart_it.S
SRCS=uart.c
OBJS=$(SRCS:.c=.o) $(SRCS:.S=.o)

all: $(OBJS)

clean:
	rm -f *.o *.exe *.dat *~

.depend: $(SRC)
	$(CC) $(CFLAGS) -MM $(SRC) > .depend

-include	.depend
