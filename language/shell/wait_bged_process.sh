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
apid1=$!
async2 &
apid2=$!

echo "main PID=$$ asynch1 PID=$apid1 asynch2 PID=$apid2" 
echo "waiting $apid1 $apid2"
wait $apid1 $apid2
echo "wait done"
exit 0
