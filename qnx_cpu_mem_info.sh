#!/bin/sh
OP_MODE=""
PATH_USAGE_FILE="/tmp/cpu_mem_info"

PATH_OUTPUT_DIR="./output"
PATH_TASKDATA_DIR="$PATH_OUTPUT_DIR/taskdata"
PATH_USAGE_CSV="$PATH_OUTPUT_DIR/cpu_mem_info.csv"
PATH_TASKLIST="$PATH_OUTPUT_DIR/tasklist"
PATH_CPUUSAGE="$PATH_OUTPUT_DIR/all_cpuusage.log"
PATH_MEMUSAGE="$PATH_OUTPUT_DIR/all_memusage.log"

DELAY="2"
COUNT="10"
AWK="/usr/bin/debug/awk"

get_cpu_mem_info()
{
	date > $PATH_USAGE_FILE
	echo "delay: $DELAY count: $COUNT output path: $PATH_USAGE_FILE"
	hogs -p 40 -S p -s $DELAY -i $COUNT -m p >> $PATH_USAGE_FILE
	date >> $PATH_USAGE_FILE
}

trans_to_csv()
{
	echo "Make ($1) to csv style"
	mkdir -p $PATH_OUTPUT_DIR

	# 1. convert to csv type
	cat $1 | while read line
	do
		echo $line | tr ' ' ',' >> $1.csv
	done

	# 2. delete date, header
	# do not work in qnx
	# cat $1.csv | grep -v "GMT\|PID" > $PATH_USAGE_CSV
	cat $1.csv | grep -v -e GMT -e PID > $PATH_USAGE_CSV
}

get_uniq_tasklist()
{
	echo "get_uniq_tasklist,$PATH_USAGE_CSV,$PATH_TASKLIST"
	# qnx sort diff with linux
	#  sort -n source
	#	1,procnto-smp-in
	#	1,[idle]
	#	1,[idle]
	#	1,procnto-smp-in
	#	1,[idle]
	#	1,procnto-smp-in
	# # sort source
	#	1,[idle]
	#	1,[idle]
	#	1,[idle]
	#	1,[idle]
	#	1,[idle]
	# cat $PATH_USAGE_CSV | cut -d',' -f1,2 | grep -v "^$" | sort -n | uniq > $PATH_TASKLIST
	cat $PATH_USAGE_CSV | cut -d',' -f1,2 | grep -v "^$" | sort | uniq | sort -n > $PATH_TASKLIST
}

split_data_per_task()
{
	rm -rf $PATH_TASKDATA_DIR
	mkdir -p $PATH_TASKDATA_DIR
	# 4. split data per task
	cat $PATH_USAGE_CSV | $AWK '/procnto-smp-in/{filename=NR".tmp"}; {print > filename}'

	cat $PATH_TASKLIST | while read line
	do
		echo $line
		for sorted_filenr in `find -maxdepth 1 -type f | grep tmp$ | cut -d'/' -f2 | cut -d'.' -f1 | sort -n`; do
			#echo "$sorted_filenr -> ./$sorted_filenr.tmp"
			filepath="./$sorted_filenr.tmp"
			output_path="$PATH_TASKDATA_DIR/`echo "$line" | cut -d';' -f1`.data"
			#echo "$line,$filepath"

			result=`grep -F $line $filepath`
			if [ "$?" == "0" ]; then
				echo $result | cut -d';' -f1,2,4,6 >> $output_path
				#echo "found, $result"
			else
				echo "$line;0%;0k" >> $output_path
				#echo "not found"
			fi

			# 4. cpu info capture
			#cat $filepath | cut -d';' -f2,3 > ../$filepath.cpu
			# 5. memory info capture
			#cat $filepath | cut -d';' -f2,6 | cut -d'k' -f1 > ../$filepath.mem
		done
	done

	rm *.tmp
}


# 5. join all data
#
# file 1          file2
# 0;[idle];42%;0k 46039090;sleep;0;0
# 0;[idle];42%;0k 46039090;sleep;0;0
# 0;[idle];39%;0k 46039090;sleep;0;0
# 0;[idle];42%;0k 46039090;sleep;0;0
#
# output
# cpu usage file
# [idle]-0,42%,42%,39%,42%
# sleep-46039090, 0,0,0,0
#
# mem usage file
# [idle]-0,0,0,0,0
# sleep-46039090,0,0,0,0

join_all_data()
{
	rm $PATH_CPUUSAGE $PATH_MEMUSAGE

	for i in `find $PATH_TASKDATA_DIR -maxdepth 1 -type f `; do
		PID_NAME=`head -n 1 $i| cut -d',' -f1,2`
		CPU_USAGE_LIST=`cat $i | cut -d',' -f3 | tr '\n' ','`
		MEM_USAGE_LIST=`cat $i | cut -d',' -f4 | tr '\n' ','`
		echo "$PID_NAME,$CPU_USAGE_LIST" >> $PATH_CPUUSAGE
		echo "$PID_NAME,$MEM_USAGE_LIST" >> $PATH_MEMUSAGE
	done
}

do_parse_data()
{
	trans_to_csv "$PATH_USAGE_FILE"
	get_uniq_tasklist
	split_data_per_task "$PATH_TASKLIST"
	join_all_data
}

do_all_stage()
{
	get_cpu_mem_info
	do_parse_data
}


# The command line help
display_help() {
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -d, --delay        sec delay(default: 2sec)"
    echo "   -c, --count        count(default: 10)"
    echo "   -o, --output       path(default:/tmp/cpu_mem_info)"
    echo "   -m, --mode		mode"
    echo "   -h, --help         show this message"
    echo
    # echo some stuff here for the -a or --add-options 
    exit 1
}

#########################
#
# start main code
#
#########################

while [[ $# -gt 0 ]]; do
	argument="$1"
	case $argument in
		--delay | -d) DELAY=$2; echo "option - delay($DELAY)"; shift; shift; ;;
		--count | -c) COUNT=$2; echo "option - count($COUNT)"; shift; shift; ;;
		--output | -o) PATH_USAGE_FILE="$2"; echo "option - output path($PATH_USAGE_FILE)"; shift; shift; ;;
		--mode | -m) OP_MODE="$2"; echo "option - mode($OP_MODE)"; shift; shift; ;;
		* ) display_help; exit 1; ;;
	esac
done

if [ "$OP_MODE" == "all" ]; then
	do_all_stage
elif [ "$OP_MODE" == "parse" ]; then
	do_parse_data
elif [ "$OP_MODE" == "info" ]; then
	get_cpu_mem_info
elif [ "$OP_MODE" == "csv" ]; then
	trans_to_csv "$PATH_USAGE_FILE"
elif [ "$OP_MODE" == "tasklist" ]; then
	get_uniq_tasklist
elif [ "$OP_MODE" == "split" ]; then
	split_data_per_task "$PATH_TASKLIST"
elif [ "$OP_MODE" == "join" ]; then
	join_all_data
else
	get_cpu_mem_info
fi
