include	Makefile.config

INCS=-I./include

GENLD=./mk_ld.sh
### SRECCONV=$(SWBASE)/tools/srecconv/srecconv
SRECCONV=srecconv
### XDAT2HEX=$(SWBASE)/tools/xdat2hex.pl
XDAT2HEX=xdat2hex.pl
### HEX2BIN=$(SWBASE)/tools/hex2bin.pl
HEX2BIN=hex2bin.pl
### SRECDUMP=$(SWBASE)/tools/srecdump/srecdump
SRECDUMP=srecdump
HEXDUMP=hexdump
HEAD=head
TAIL=tail

# SUBDIRS=boot drivers uart math
SUBDIRS=boot drivers uart

ROMFILES=boot/newboot.o
ROMFILES+=boot/init.o

# ROMFILES+=drivers/leds.o
ROMFILES+=drivers/sleep.o

ROMFILES+=uart/uart.o
# ROMFILES+=uart/uart_it.o

# ROMFILES+=timer/timer.o
# ROMFILES+=timer/timer_it.o

# FIXME : TODO : reintegrer math (si necessaire?) une fois l'api stabilisee..
#ROMFILES+=math/sin_table.o

ROMFILES+=boot/trap.o
ROMFILES+=main.o

#all: rom.ld rom.srec roms flash
all: rom.ld rom.srec roms patch_vhdl

roms: ST_ROMHS_8192x32m16_L_low.bin.cde ST_ROMHS_8192x32m16_L_high.bin.cde
	head -n 4096 ST_ROMHS_8192x32m16_L_low.cde > /tmp/soft_boot.hex

push: roms
	sshpass -p "" scp /tmp/soft_boot.hex root@192.168.0.200:/tmp/soft_boot.hex 2>/dev/null; true
	@echo DONE

patch_vhdl: roms
	rom_patch
	cp -f ./rom32k_virtex5.vhd ../src/rom32k_cyclone4.vhd

rom.exe: rom.ld subdirs $(ROMFILES)
	$(LD) -T rom.ld -o $@
	$(OBJCOPY) --remove-section=.comment $@
###	$(STRIP) $@

ST_ROMHS_8192x32m16_L_low.cde: rom.bin
	$(HEAD) -c 32768 $< | $(HEXDUMP) -v -e '4/1 "%02X" "\n"' > $@

ST_ROMHS_8192x32m16_L_high.cde: rom.bin
	$(TAIL) -c 32768 $< | $(HEXDUMP) -v -e '4/1 "%02X" "\n"' > $@

%.bin.cde: %.cde
	$(HEX2BIN) $< > $@

rom.bin: rom.srec
	$(SRECDUMP) $< $@ 0 65536

rom.ld: $(GENLD)
	$(GENLD) rom $(ROMFILES) > $@

.PHONY: subdirs $(SUBDIRS) clean

subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean:
	for dir in $(SUBDIRS); do $(MAKE) clean -C $$dir; done
	rm -f *.o *.a *.exe *.srec *.dat *~
	rm -f rom.ld rom.bin rom.hex rom.exe
	rm -f user.ld
	rm -f ST_ROMHS_8192x32m16_L_*.cde
	rm -f rom32k_virtex5.vhd

.PHONY: check test

SHELL = /bin/bash

test check:
	@pgrep >&/dev/null aksusb   && echo "AKSUSB   daemon is running" || echo "AKSUSB   daemon is not running!"
	@pgrep >&/dev/null winehasp && echo "WINEHASP daemon is running" || echo "WINEHASP daemon is not running!"
	@pgrep >&/dev/null hasplm   && echo "HASPLM   daemon is running" || echo "HASPLM   daemon is not running!"
