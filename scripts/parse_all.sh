#!/bin/bash
# set -xve

printUsage() {
	echo "$(basename $0) <result_dir>"
}

getMicroCmd() {
	# Delete files to record timestamp.
	[[ -f $1.start ]] && rm $1.start
	[[ -f $1.fsync ]] && rm $1.fsync
	[[ -f $1.end ]] && rm $1.end

	while read -r line; do
		# echo "$line"
		if [[ $line == "Command:"* ]]; then
			cmd_opt=$(echo $line | sed 's/.*tput_micro//g' | xargs)
			op=$(echo "$cmd_opt" | cut -d" " -f4)
			file_size=$(echo "$cmd_opt" | cut -d" " -f5 | cut -d"M" -f1)
			io_size=$(echo "$cmd_opt" | cut -d" " -f6)
			thread_num=$(echo "$cmd_opt" | cut -d" " -f7)

			echo -n "$op,$file_size,$io_size,$thread_num,"
		fi

		if [[ $line == "Benchmark starts at:"* ]]; then
			start_time=$(echo "$line" | cut -d " " -f4)
			# echo "start: $start_time"
			echo $start_time >>"$1.start"
		elif [[ $line == "Fsync at:"* ]]; then
			fsync_time=$(echo "$line" | cut -d " " -f3)
			# echo "fsync: $fsync_time"
			echo $fsync_time >>"$1.fsync"
		elif [[ $line == "Benchmark ends at:"* ]]; then
			end_time=$(echo "$line" | cut -d " " -f4)
			# echo "end: $end_time"
			echo $end_time >>"$1.end"
		fi

	done <"$1"
}

getCpuUsage() {
	parse_first_line=0
	while read -r line; do
		if [[ $parse_first_line = 0 ]]; then
			parse_first_line=1
			start_time=$(echo "$line" | cut -d " " -f1)
			echo -n "$start_time,"
		fi
		cpu_usage=$(echo "$line" | xargs | cut -d " " -f10)
		echo -n "$cpu_usage,"
	done <"$1"

	echo ""
}

# $1 = tput result dir: results/tput
parseMicroTput() {

	# Parse throughput.
	echo "### Throughput (filesize=MB, aggtput=MB/s) ###"
	echo "name,op,filesize,iosize,threads,aggtput"
	for d in $1/*; do
		if ! [ -d "$d" ]; then
			continue
		fi
		for f in $(find $d -type f -name "*.out"); do
			filename=$(basename $f)
			op=$(echo $filename | cut -d "_" -f1)
			# iosize=$(echo $filename | cut -d "_" -f2)
			# thnum=$(echo $filename | cut -d "_" -f3 | cut -d "t" -f1)
			# filetype=$(echo $filename | cut -d "." -f2)

			# echo -n "$op,$iosize,$thnum,"
			echo -n "$(basename $d),"
			getMicroCmd $f
			scripts/parse_tput.sh $op "$(cat $f)"

		done
	done

	# Parse CPU utilization.
	echo "### CPU Utilization (% every second, 100% = 1 core) ###"
	echo "name,op,iosize,threads,start(timestamp),cpuutil..."
	for d in $1/*; do
		if ! [ -d "$d" ]; then
			continue
		fi

		for f in $(find $d -type f -name "*.cpu"); do
			filename=$(basename $f)
			op=$(echo $filename | cut -d "_" -f1)
			iosize=$(echo $filename | cut -d "_" -f2)
			thnum=$(echo $filename | cut -d "_" -f3 | cut -d "t" -f1)
			filetype=$(echo $filename | cut -d "." -f2)

			echo -n "$(basename $d),${op},${iosize},${thnum},"

			getCpuUsage $f
		done
	done
}

# $1 = lat result dir results/lat
parseMicroLat() {
	echo "Lat"
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

	if [ -z $1 ] || [ $1 = "-h" ] || [ $1 = "--help" ]; then
		printUsage
	fi

	for dir in "$1/*"; do
		if [ $(basename $dir) = "tput" ]; then
			parseMicroTput $dir
		elif [ $(basename $dir) = "lat" ]; then
			parseMicroLat $dir
		fi
	done
fi
