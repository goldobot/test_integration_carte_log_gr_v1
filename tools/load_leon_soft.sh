#!/bin/sh
FILE=$1
#IFS='\n'
for LINE in `cat $FILE`
do
        echo $LINE
        i2c 0x42 wb4 0x02 0x$LINE
done
exit 0


