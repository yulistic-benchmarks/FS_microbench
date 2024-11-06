#!/bin/bash
# set -xe
#
# PERF_BIN="perf" # Set correct perf bin path.
PERF_BIN="/lib/modules/$(uname -r)/source/tools/perf/perf" # Set correct perf bin path.

printUsage() {
	echo "$(basename $0) <result_dir>"
}

getTputMicroCmd() {
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
			io_size=$(numfmt --from=iec $io_size)
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

getAggrCPUUsage() {
	f_name=$(basename $1 | cut -d "." -f 1)
	d_path=$(dirname $1)
	report_file="${d_path}/${f_name}.report"

	# sudo $PERF_BIN report --sort overhead -i $1 -F overhead,pid,period,socket --stdio > $report_file
	sudo $PERF_BIN report --sort overhead -i $1 -F overhead,comm,period,socket --stdio >$report_file

	# cat only the processes that consumes more than 1% of CPU.
	cat $report_file | grep -v -E " 0...%|#" >${d_path}/${f_name}.cpu
}

### top
# getCpuUsage() {
# 	parse_first_line=0
# 	while read -r line; do
# 		if [[ $parse_first_line = 0 ]]; then
# 			parse_first_line=1
# 			start_time=$(echo "$line" | cut -d " " -f1)
# 			echo -n "$start_time,"
# 		fi
# 		cpu_usage=$(echo "$line" | xargs | cut -d " " -f10)
# 		echo -n "$cpu_usage,"
# 	done <"$1"

# 	echo ""
# }

### iostat
getCpuUsage() {
	parse_first_line=0
	while read -r line; do
		if [[ $parse_first_line = 0 ]]; then
			parse_first_line=1
			start_time=$(echo "$line" | cut -d " " -f1)
			echo -n "$start_time,"
		fi
		cpu_idle=$(echo "$line" | xargs | cut -d " " -f7)

		# cpu usage = 100 - idle
		cpu_usage=$(awk "BEGIN {print 100.00 - $cpu_idle}")
		# cpu_usage=$(echo "100.00 $cpu_idle" | awk '{printf "%.2f", $1 - $2}')
		echo -n "$cpu_usage,"
	done <"$1"

	echo ""
}

getCpuCycles() {
	if [ -f $1 ]; then
		cpu_cycles=$(grep "Event count" $1 | xargs | cut -d ' ' -f 5)
		echo -n "$cpu_cycles"
	fi
}

# $1 = tput result dir: results/tput
parseMicroTput() {

	echo "Extracting CPU usage from perf data."
	for d in $1/*; do
		if ! [ -d "$d" ]; then
			continue
		fi

		for f in $(find $d -type f -name "*.perfdata"); do
			getAggrCPUUsage $f
		done
	done

	# Parse throughput.
	echo "### Throughput (filesize=MB aggtput=MB/s) ###"
	echo "name,op,filesize,iosize,threads,aggtput,cycles"
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

			getTputMicroCmd $f

			scripts/parse_tput.sh $op "$(cat $f)"

			getCpuCycles "${f%.*}".report

			echo ""
		done
	done

	# Parse CPU utilization. (top or iostat)
	#	echo "### CPU Utilization (% every second, 100% = 1 core) ###"
	#	echo "name,op,iosize,threads,start(timestamp),cpuutil..."
	#	for d in $1/*; do
	#		if ! [ -d "$d" ]; then
	#			continue
	#		fi
	#
	#		for f in $(find $d -type f -name "*.cpu"); do
	#			filename=$(basename $f)
	#			op=$(echo $filename | cut -d "_" -f1)
	#			iosize=$(echo $filename | cut -d "_" -f2)
	#			thnum=$(echo $filename | cut -d "_" -f3 | cut -d "t" -f1)
	#			filetype=$(echo $filename | cut -d "." -f2)
	#
	#			echo -n "$(basename $d),${op},${iosize},${thnum},"
	#
	#			getCpuUsage $f
	#		done
	#	done

}

getLatMicroCmd() {
	while read -r line; do
		# echo "$line"
		if [[ $line == "Command:"* ]]; then
			cmd_opt=$(echo $line | sed 's/.*lat_micro//g' | xargs)
			op=$(echo "$cmd_opt" | cut -d" " -f4)
			file_size=$(echo "$cmd_opt" | cut -d" " -f5 | cut -d"M" -f1)
			io_size=$(echo "$cmd_opt" | cut -d" " -f6)
			io_size=$(numfmt --from=iec $io_size)
			thread_num=$(echo "$cmd_opt" | cut -d" " -f7)

			echo -n "$op,$file_size,$io_size,$thread_num,"
		fi
	done <"$1"
}

# $1 = lat result dir results/lat
parseMicroLat() {
	# Parse latency.
	echo "### Latency (filesize=MB latency=us) ###"
	echo "name,op,filesize,iosize,threads,avg,min,max,std,p50,p99,p999,p9999,p99999,[fsync_avg],cycles"
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

			# set -xe
			getLatMicroCmd $f
			# set +xe

			scripts/parse_lat.sh $op "$(cat $f)"

			echo ""
		done
	done
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

	if [ -z $1 ] || [ $1 = "-h" ] || [ $1 = "--help" ]; then
		printUsage
	fi

	for dir in $1/*; do
		if [ $(basename $dir) = "tput" ]; then
			parseMicroTput $dir > tput_result.txt

			# Sort and print.
			cat tput_result.txt | head -n 3
			cat tput_result.txt | tail -n +4 | sort -t, -k2,2 -k1,1 -k4,4n -k5,5n
			rm tput_result.txt


		elif [ $(basename $dir) = "lat" ]; then
			parseMicroLat $dir > lat_result.txt

			# Sort and print.
			cat lat_result.txt | head -n 2
			cat lat_result.txt | tail -n +3 | sort -t, -k2,2 -k1,1 -k4,4n
			rm lat_result.txt

		fi
	done


fi
