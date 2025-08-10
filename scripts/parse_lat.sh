#!/bin/bash
# set -xve

printUsage() {
	echo "Usage: ./$(basename "$0") [sw|sr|rw|rr] <log string>"
	echo "	Example: ./$(basename "$0") sw \"\$(cat test.log)\""
	echo "Output format: avg,min,max,std,p_50,p_99,p_999,p_9999,p_99999,[fsync_avg]"
}

parseLog() {
	while IFS= read -r line; do
		# echo "$line" | xargs
		# The order of conditions are important.
		if [[ "$line" == *"fsync-avg:"* ]]; then
			fsync_avg=$(awk -F'[ ()]+' '{ $1=$1; print $4 }' <<< "$line")
		elif [[ "$line" == *"avg:"* ]]; then
			avg=$(awk -F'[ ()]+' '{ $1=$1; print $4 }' <<< "$line")
		elif [[ "$line" == *"min:"* ]]; then
			min=$(awk -F'[ ()]+' '{ $1=$1; print $4 }' <<< "$line")
		elif [[ "$line" == *"max:"* ]]; then
			max=$(awk -F'[ ()]+' '{ $1=$1; print $4 }' <<< "$line")
		elif [[ "$line" == *"std:"* ]]; then
			std=$(awk -F'[ ()]+' '{ $1=$1; print $4 }' <<< "$line")
		elif [[ "$line" == *"50 percentile"* ]]; then
			p_50=$(awk -F'[ ()]+' '{ $1=$1; print $6 }' <<< "$line")
		elif [[ "$line" == *"99.999 percentile"* ]]; then
			p_99999=$(awk -F'[ ()]+' '{ $1=$1; print $5 }' <<< "$line")
		elif [[ "$line" == *"99.99 percentile"* ]]; then
			p_9999=$(awk -F'[ ()]+' '{ $1=$1; print $6 }' <<< "$line")
		elif [[ "$line" == *"99.9 percentile"* ]]; then
			p_999=$(awk -F'[ ()]+' '{ $1=$1; print $6 }' <<< "$line")
		elif [[ "$line" == *"99 percentile"* ]]; then
			p_99=$(awk -F'[ ()]+' '{ $1=$1; print $6 }' <<< "$line")
		fi
		# echo "avg=$avg min=$min max=$max std=$std p_50=$p_50 p_99=$p_99 p_999=$p_999 p_9999=$p_9999 p_99999=$p_99999 fsync_avg=$fsync_avg"
	done < <(printf '%s\n' "$1")

	echo -n "$avg,$min,$max,$std,$p_50,$p_99,$p_999,$p_9999,$p_99999,$fsync_avg,"
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
