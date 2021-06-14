#!/bin/sh
# https://www.unix.com/shell-programming-and-scripting/151040-asynchronous-shell-scripts-question-newbie.html
async1()
{
   sleep 5
   echo "from async 1"
   sleep 5
   echo "async 1 finished"
}

async2()
{
   sleep 3
   echo "from async 2"
   sleep 4
   echo "async 2 finished"
}

echo "main before"
async1 &
echo "$!" >> /tmp/async_list
async2 &
echo "$!" >> /tmp/async_list

for i in `cat /tmp/async_list`; do
	echo "wait [$i]"
	wait $i
done

echo "wait done"
exit 0
