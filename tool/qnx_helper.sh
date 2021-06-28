#!/bin/sh

OP_MODE=""
PATH_INPUT=""
PATH_DIR=""

# The command line help
display_help() {
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -m, --mode         mode"
    echo "   -i, --input	pathinfo"
    echo "   -h, --help         show this message"
    echo
    exit 1
}

do_restart_dlt()
{
	echo "start to rm dlt files and restart dlt-daemon"
	kill -9 `ps -A | grep dlt-daemon | tr -s ' ' | cut -d' ' -f2`
	rm -rf /log/dlt_offlinetrace.*
	dlt-daemon -d -c /usr/local/etc/dlt.conf
	echo "done"
}

cp_to_qnx()
{
	path_filename="$1"
	path_dest_dir="/tmp"

	echo "Copy $path_filename to $path_dest_dir(QNX)"
	scp -P 10022 $path_filename root@192.168.105.100:$path_dest_dir
}

cp_from_qnx()
{
	path_filename="$1"
	path_source_dir="$2"

	echo "Copy $path_filename from $path_source_dir(QNX)"
	scp -P 10022 -r root@192.168.105.100:/$path_source_dir/$path_filename .
}


#########################
#
# start main code
#
#########################

while [[ $# -gt 0 ]]; do
        argument="$1"
        case $argument in
                --mode | -m) OP_MODE="$2"; echo "option - mode($OP_MODE)"; shift; shift; ;;
		--input | -i) PATH_INPUT="$3"; PATH_DIR="$2"; echo "option - input($PATH_INPUT,$PATH_DIR)"; shift; shift; shift; ;;
                * ) display_help; exit 1; ;;
        esac
done

if [ "$OP_MODE" == "restart_dlt" ]; then
	do_restart_dlt
elif [ "$OP_MODE" == "toqnx" ]; then
	cp_to_qnx $PATH_INPUT $PATH_DIR
elif [ "$OP_MODE" == "fromqnx" ]; then
	cp_from_qnx $PATH_INPUT $PATH_DIR
else
        get_cpu_mem_info "$PATH_USAGE_FILE"
fi
