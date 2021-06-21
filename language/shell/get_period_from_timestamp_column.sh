#!/bin/sh

turn_on_signal=0
turn_on_time=0
turn_off_time=0
period_time=0

cat sample_dlt.log |
while IFS= read -r line; do
	if echo $line | grep -q "\- data :"; then
                 if echo $line | grep -q "DID\"\":55"; then
			# get timestamp
			 turn_on_signal=1

			# error occured below
			#
			# (standard_in) 1: syntax error
			#
			#turn_on_time=`echo $line | cut -d',' -f2`
			 turn_on_time=`echo $line | cut -d',' -f2 | tr -d '"'`
                         echo "turn on=$turn_on_time"
                 else
			# get timestamp and calculate period(CURR - PREV)
			 turn_off_time=`echo $line | cut -d',' -f2 | tr -d '"'`
                         echo "turn off=$turn_off_time"
			 if [ "$turn_on_signal" == 1 ]; then
				 period_time=`echo "$turn_off_time - $turn_on_time" | bc`
				 echo "period=$period_time,$turn_off_time,$turn_on_time"
				 turn_on_signal=0
			 fi
                 fi
         else
                 echo "invalid"
         fi
done
