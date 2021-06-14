#!/bin/sh
OP_MODE=""
PATH_USAGE_FILE="/tmp/cpu_mem_info"
PATH_USAGE_DATA=$PATH_USAGE_FILE

PATH_OUTPUT_DIR="./output"
PATH_TASKDATA_DIR="$PATH_OUTPUT_DIR/taskdata"
PATH_USAGE_CSV="$PATH_OUTPUT_DIR/cpu_mem_info.csv"
PATH_TASKLIST="$PATH_OUTPUT_DIR/tasklist"
PATH_CPUUSAGE="$PATH_OUTPUT_DIR/all_cpuusage.log"
PATH_MEMUSAGE="$PATH_OUTPUT_DIR/all_memusage.log"

HOGS_HEADER="PID           NAME  MSEC PIDS  SYS       MEMORY"

DELAY="2"
COUNT="10"
AWK="awk"
PATH_QNX_AWK="/usr/bin/debug/awk"

env_setup()
{
	# awk's original place is mounted with readonly and awk not executable
	# so we cp it to rw area and set it executable
	if [ ! -x "$AWK" ]; then
		echo "awk setup is needed"
	else
		echo "awk is runnable, setup exit"
		return
	fi

	if [ -f  "$PATH_QNX_AWK" ]; then
		if [ ! -x "$PATH_QNX_AWK" ]; then
			echo "awk is placed at $PATH_QNX_AWK and but not executable, cp to /tmp/bin and chmod it"
			cp $PATH_QNX_AWK /tmp/bin/awk
			chmod +x /tmp/bin/awk
			AWK="/tmp/bin/awk"
		else
			echo "qnx is placed at $PATH_QNX_AWK and it executable, use it"
		fi
	fi
}

get_cpu_mem_info()
{
	rm -rf $1
	date >> $1
	echo "delay: $DELAY count: $COUNT output path: $1"
	hogs -p 40 -S p -s $DELAY -i $COUNT -m p >> $1
	date >> $1
}

# re-write function to handle qnx exception
# qnx's hogs show entry without process name
trans_to_csv()
{
	echo "trans_to_csv,$1,$PATH_USAGE_CSV"
	mkdir -p $PATH_OUTPUT_DIR
	rm -rf $PATH_USAGE_CSV output/col_name

	path_tmp_csv="$PATH_OUTPUT_DIR/$1.tmp"

	cat $1 | grep -v -e GMT -e "$HOGS_HEADER" -e "^$" > $path_tmp_csv
	cat $path_tmp_csv | cut -c 1-10 | tr -d ' ' > $PATH_OUTPUT_DIR/col_pid
	cat $path_tmp_csv | cut -c 11-24 | tr -d ' ' > $PATH_OUTPUT_DIR/col_name.tmp
	cat $path_tmp_csv | cut -c 25-30 | tr -d ' ' > $PATH_OUTPUT_DIR/col_msec
	cat $path_tmp_csv | cut -c 31-35 | tr -d ' ' > $PATH_OUTPUT_DIR/col_pids
	cat $path_tmp_csv | cut -c 36-40 | tr -d ' ' > $PATH_OUTPUT_DIR/col_sys
	cat $path_tmp_csv | cut -c 41-48 | tr -d ' ' > $PATH_OUTPUT_DIR/col_mem

	cat $PATH_OUTPUT_DIR/col_name.tmp | while read line; do
		if [ "$line" == "" ]; then
			echo "NO_NAME" >> $PATH_OUTPUT_DIR/col_name
		else
			echo $line >> $PATH_OUTPUT_DIR/col_name
		fi
	done

	paste -d',' \
		$PATH_OUTPUT_DIR/col_pid \
		$PATH_OUTPUT_DIR/col_name\
		$PATH_OUTPUT_DIR/col_msec\
		$PATH_OUTPUT_DIR/col_pids\
		$PATH_OUTPUT_DIR/col_sys\
		$PATH_OUTPUT_DIR/col_mem > $PATH_USAGE_CSV

	# parse sub-command use it
	#
	# 0,[idle],./cpu_mem_info.tmp
	# ...
	# 794707,cpu_lockup_cli,./cpu_mem_info.tmp
	rm -rf $path_tmp_csv
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
		for sorted_filenr in `find -maxdepth 1 -type f | grep tmp$ | cut -d'/' -f2 | cut -d'.' -f1 | sort -n`; do
			#echo "$sorted_filenr -> ./$sorted_filenr.tmp"
			filepath="./$sorted_filenr.tmp"
			output_path="$PATH_TASKDATA_DIR/`echo "$line" | cut -d',' -f1`.data"
			echo "$line,$filepath"

			result=`grep -F $line $filepath`
			if [ "$?" == "0" ]; then
				echo $result | cut -d',' -f1,2,4,6 >> $output_path
				#echo "found, $result"
			else
				echo "$line,0%,0k" >> $output_path
				#echo "not found"
			fi

			# 4. cpu info capture
			#cat $filepath | cut -d';' -f2,3 > ../$filepath.cpu
			# 5. memory info capture
			#cat $filepath | cut -d';' -f2,6 | cut -d'k' -f1 > ../$filepath.mem
		done
	done

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
	trans_to_csv "$PATH_USAGE_DATA"
	get_uniq_tasklist
	split_data_per_task "$PATH_TASKLIST"
	join_all_data
}

do_all_stage()
{
	get_cpu_mem_info "$PATH_USAGE_FILE"
	do_parse_data
	rm *.tmp
}


# The command line help
display_help() {
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -d, --delay        capture delay(default: 2sec)"
    echo "   -c, --count        capture count(default: 10)"
    echo "   -o, --output       capture data output path(default:/tmp/cpu_mem_info)"
    echo "   -m, --mode         mode(default: get cpu memory info
    				all: get cpu memory info & parse data
				parse: parse data"
    echo "   -i, --input        cpu memory info path"
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
		--input | -i) PATH_USAGE_DATA="$2"; echo "option - usage data path($PATH_USAGE_DATA)"; shift; shift; ;;
		* ) display_help; exit 1; ;;
	esac
done

env_setup

if [ "$OP_MODE" == "all" ]; then
	do_all_stage
elif [ "$OP_MODE" == "parse" ]; then
	do_parse_data
elif [ "$OP_MODE" == "info" ]; then
	get_cpu_mem_info "$PATH_USAGE_FILE"
elif [ "$OP_MODE" == "csv" ]; then
	trans_to_csv "$PATH_USAGE_DATA"
elif [ "$OP_MODE" == "tasklist" ]; then
	get_uniq_tasklist
elif [ "$OP_MODE" == "split" ]; then
	split_data_per_task "$PATH_TASKLIST"
elif [ "$OP_MODE" == "join" ]; then
	join_all_data
else
	get_cpu_mem_info "$PATH_USAGE_FILE"
fi
