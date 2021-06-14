#!/bin/sh


func1()
{
	echo "sleep,$i,start"
	sleep $1
	echo "sleep,$i,done"
}

for i in 1 2 3 4 5; do
	func1 $i &
done

for i in `jobs -p`; do
	wait $i
done

