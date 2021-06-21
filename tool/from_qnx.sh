#!/bin/sh

QNX_WORK_PATH=$1
FILE_NAME=$2

echo "Copy $FILE_NAME from $QNX_WORK_PATH(QNX)"

scp -P 10022 -r root@192.168.105.100:/$QNX_WORK_PATH/$FILE_NAME .

#mv $FILE_NAME output/$(date +"%Y%m%d")
