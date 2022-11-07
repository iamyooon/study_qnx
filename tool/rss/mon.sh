#!/bin/sh

env_setup()
{

	echo "wewake - setup env"
	mount -o remount,rw /
	echo "wewake - setup done"
}

restore()
{
	echo "wewake - restore"
}

mon_start()
{
	echo "wewake - start memleak monitor"

	i=0
	cnt=$1
	mount -o remount,rw /
	while [[ $cnt -gt 0 ]]; do
		echo "wewake - ($(($i+1))/$1)"
		date
		ps -Ao pid,comm,sz | grep -e cclusterhmi\
					  -e cmonitorservice\
					  -e ctaskservice\
					  -e cvehicleservice\
					  -e chwioservice\
					  -e cwelcomservice\
					  -e cupdateservice\
					  -e clifecycleservice\
					  -e cuserservice\
					  -e cappservice\
					  -e csystemmonitorservice\
					  -e cdiagnosisservice\
					  -e civcservice\
					  -e cmonitorservice\
					  -e cfactoryservice\
					  -e cvehicleinfomanager\
					  -e ceventmanager\
					  -e cecumanager\
					  -e cclusterhmi\
					  -e ctelltalehmi\
					  -e valgrind > /log/$i.rss
		if [ $i == "0" ]; then
			cat /log/$i.rss
		else
			paste /log/1.rss /log/$i.rss
		fi

		i=$(($i+1))
		cnt=$((cnt-1))
		sleep $2
	done
}

if [ "$1" == "setup" ]; then
	env_setup
elif [ "$1" == "restore" ]; then
	restore
elif [ "$1" == "rss" ]; then
	on -p 20r ./mon.sh $2 $3
else
	mon_start $1 $2
fi
