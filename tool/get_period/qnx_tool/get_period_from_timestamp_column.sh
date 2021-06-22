#!/bin/sh

turn_on_signal=0
turn_on_time=0
turn_off_time=0
period_time=0

while read line; do
	if echo $line | grep TLTL | grep -q "\-,data,:"; then
                if echo $line | grep -q "DID\":55"; then
			# get timestamp
			turn_on_signal=1

			# error occured below
			#
			# (standard_in) 1: syntax error
			#
			#turn_on_time=`echo $line | cut -d',' -f2`
			turn_on_time=`echo $line | cut -d',' -f3 | tr -d '"'`
                        echo "turn on=$turn_on_time"
                elif [ "$turn_on_signal" == "1" ]; then
			# get timestamp and calculate period(CURR - PREV)
			turn_off_time=`echo $line | cut -d',' -f3 | tr -d '"'`
                        echo "turn off=$turn_off_time"
			if [ "$turn_on_signal" == 1 ]; then
				period_time=`echo "$turn_off_time - $turn_on_time" | bc`
				#echo "period=$period_time,$turn_off_time,$turn_on_time"
				echo "wewake: $period_time(period), $turn_on_time(turn on),$turn_off_time(turn off)"
				turn_on_signal=0
			fi
		#else
			#echo "turn off"
                fi
        #else
                #echo "invalid"
        fi
done
