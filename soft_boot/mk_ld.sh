#!/bin/bash

# 08/09/2011: LT
# add a "testing" parameter, in this mode:
#   "loader/*" are removed from the ld strict (since loader is in this case loader() is in crt0b.c file)
#   replace "get_applet" entry point by "loader" entry point 

function usage {
    echo "$0 [rom|exe|testing] <rom_objects>"
    exit -1
}

if [ $# -lt 1 ]
then
    usage
fi

MODE="$1"

case $1 in
rom|exe|testing)
	;;
*)
	usage
	;;
esac

shift

cat <<EOF
/* OUTPUT_FORMAT(srec) */
OUTPUT_ARCH(sparc)
EOF

echo "ENTRY(_rom_text_start)"

cat <<EOF
PROVIDE(__RAM_BEGIN = 0x40000000);
PROVIDE(__RAM_END = __RAM_BEGIN + 8k);
PROVIDE(_stack_top = __RAM_END - 16);

MEMORY {
  rom     : ORIGIN = 0x00000000, LENGTH = 16k
  ram     : ORIGIN = 0x40000000, LENGTH = 8k
}

SECTIONS {
EOF

# text section of rom code
echo -n "  .rom_text"
if [ "$MODE" = exe ]
then
    echo -n " (NOLOAD)"
fi
echo " : {"
echo "    _rom_text_start = .;"
for i in "$@"
do
    if [[ "$MODE" = testing && "${i:0:7}" = "loader/" ]]
    then
       continue
    fi
    if [ "$i" = "boot/trap.o" ]
    then
# trap_handler must be aligned on 4096 boundary
	echo "    . = ALIGN(4096);"
    fi
    echo "    $i (*text*)"
done
echo "    _rom_text_end = .;"
echo "  } > rom"

# rodata section of rom code
echo -n "  .rom_rodata BLOCK(0x10)"
if [ "$MODE" = exe ]
then
    echo -n " (NOLOAD)"
fi
echo " : {"
echo "    _rom_rodata_start = .;"
for i in "$@"
do
    if [[ "$MODE" = testing && "${i:0:7}" = "loader/" ]]
    then
       continue
    fi
    echo "    $i (*rodata*)"
done
echo "    _rom_rodata_end = .;"
echo "  } > rom"

# data section of rom code
echo -n "  .rom_data"
if [ "$MODE" = exe ]
then
    echo -n " (NOLOAD)"
fi
echo " : AT(ADDR(.rom_rodata) + SIZEOF(.rom_rodata)) {"
echo "    _rom_data_start = .;"
for i in "$@"
do
    if [[ "$MODE" = testing && "${i:0:7}" = "loader/" ]]
    then
       continue
    fi
    echo "    $i (*data*)"
done
echo "    _rom_data_end = .;"
echo "  } > ram"

# bss section of rom code
echo -n "  .rom_bss BLOCK(0x10)"
if [ "$MODE" = exe ]
then
    echo -n " (NOLOAD)"
fi
echo " : {"
echo "    _rom_bss_start = .;"
for i in "$@"
do
    if [[ "$MODE" = testing && "${i:0:7}" = "loader/" ]]
    then
       continue
    fi
    echo "    $i (.bss)"
    echo "    $i (COMMON)"
done
echo "    _rom_bss_end = .;"
echo "  } > ram"


cat <<EOF
  .data BLOCK(0x10) : {
    _data_start = .;
    *(*data*);
    *(*rodata*);
    _data_end = .;
  } > ram
EOF

echo "}"
