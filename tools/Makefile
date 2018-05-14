CC = /opt/gumstix/bin/arm-linux-uclibc-gcc
COPTS = -O0 --static
#LIBOPTS = -lm
LIBOPTS = 

TARGETS = load_leon_soft

$(TARGET): $(TARGET).c
	$(CC) $(COPTS) $< -o $@ $(LIBOPTS)

all: clean
	@for FI in $(TARGETS); do make TARGET=$$FI; printf '\n'; done

clean:
	@for FI in $(TARGETS); do \
		if [ -f $$FI ]; then    \
			echo "rm $$FI";       \
			rm $$FI;              \
		fi;                     \
	done


