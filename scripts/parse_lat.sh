#!/bin/bash
# set -xve

printUsage() {
	echo "Usage: ./$(basename "$0") [sw|sr|rw|rr] <log string>"
	echo "	Example: ./$(basename "$0") sw \"\$(cat test.log)\""
	echo "Output format: avg,min,max,std,p_50,p_99,p_999,p_9999,p_99999,[fsync_avg]"
	exit
}

parseLog() {

	while IFS= read -r line; do
		# echo "$line" | xargs
		# The order of conditions are important.
		if [[ "$line" == *"fsync-avg:"* ]]; then
			fsync_avg=$(echo "$line" | xargs | cut -d " " -f4 | cut -d "(" -f2)
		elif [[ "$line" == *"avg:"* ]]; then
			avg=$(echo "$line" | xargs | cut -d " " -f4 | cut -d "(" -f2)
		elif [[ "$line" == *"min:"* ]]; then
			min=$(echo "$line" | xargs | cut -d " " -f4 | cut -d "(" -f2)
		elif [[ "$line" == *"max:"* ]]; then
			max=$(echo "$line" | xargs | cut -d " " -f4 | cut -d "(" -f2)
		elif [[ "$line" == *"std:"* ]]; then
			std=$(echo "$line" | xargs | cut -d " " -f4 | cut -d "(" -f2)
		elif [[ "$line" == *"50 percentile"* ]]; then
			p_50=$(echo "$line" | xargs | cut -d " " -f6 | cut -d "(" -f2)
		elif [[ "$line" == *"99.999 percentile"* ]]; then
			p_99999=$(echo "$line" | xargs | cut -d " " -f5 | cut -d "(" -f2)
		elif [[ "$line" == *"99.99 percentile"* ]]; then
			p_9999=$(echo "$line" | xargs | cut -d " " -f6 | cut -d "(" -f2)
		elif [[ "$line" == *"99.9 percentile"* ]]; then
			p_999=$(echo "$line" | xargs | cut -d " " -f6 | cut -d "(" -f2)
		elif [[ "$line" == *"99 percentile"* ]]; then
			p_99=$(echo "$line" | xargs | cut -d " " -f6 | cut -d "(" -f2)
		fi
		# echo "avg=$avg min=$min max=$max std=$std p_50=$p_50 p_99=$p_99 p_999=$p_999 p_9999=$p_9999 p_99999=$p_99999 fsync_avg=$fsync_avg"
	done < <(printf '%s\n' "$1")

	echo "$avg,$min,$max,$std,$p_50,$p_99,$p_999,$p_9999,$p_99999,$fsync_avg"
}

if [ "$#" -ne 2 ]; then
	printUsage
	exit
fi

op=$1

# fsync-avg is the only difference.
if [ "$op" = "sw" ]; then
	parseLog "$2"

elif [ "$op" = "sr" ]; then
	parseLog "$2"

elif [ "$op" = "rw" ]; then
	parseLog "$2"

elif [ "$op" = "rr" ]; then
	parseLog "$2"
fi
