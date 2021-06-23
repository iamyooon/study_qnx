#!/bin/sh

if [ -d output ]; then
	echo "output directory exist, remove it"
	rm -rf output
fi

mkdir output

echo "remove unnecessary first line from kev.csv"
tail -n +2 kev.csv > output/header_data

echo "remove unnecessary blank between comma"
cat output/header_data | sed  's/, /,/g' > output/header_data_rm-blank.csv

echo "backup Control Events, System class event"
cat output/header_data_rm-blank.csv | grep ",," > output/not_proc_event

echo "get process,thread list from output/header_data_rm-blank.csv"
cat output/header_data_rm-blank.csv | cut -d',' -f5 | sort  | uniq | grep -v "^$" > output/proc_thread_list

task_nr=`wc -l output/proc_thread_list`
echo "split $task_nr event from output/header_data_rm-blank.csv to output/*.log"
mkdir output/per_proc_events
cat output/proc_thread_list | while read taskname; do
	normalized_name=`echo $taskname | tr -dc '[:alnum:]\n\r'`
	#echo "split log from output/header_data_rm-blank.csv to output/$line.log"
	echo "grep $taskname output/header_data_rm-blank.csv > output/per_proc_events/$normalized_name.log"
	grep ",$taskname," output/header_data_rm-blank.csv > output/per_proc_events/"$normalized_name".log
done

