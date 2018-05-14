include	../Makefile.config

SRCS=
# SRCS+=leds.c
SRCS+=sleep.c
OBJS=$(SRCS:.c=.o)

all: $(OBJS)

clean:
	rm -f *.o *.exe *.dat

.depend: $(SRCS)
	$(CC) $(CFLAGS) -MM $(SRCS) > .depend

-include	.depend
