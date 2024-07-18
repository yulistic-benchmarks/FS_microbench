#!/bin/bash
# set -xve

printUsage() {
	echo "Usage: ./$(basename "$0") [sw|sr|rw|rr] <log string>"
	echo "	Example: ./$(basename "$0") sw \"\$(cat test.log)\""
	echo "Output is Aggregated throughput in MB/s."
}

parseLog() {
	while IFS= read -r line; do
		# echo "$line" | xargs
		# The order of conditions are important.
		if [[ "$line" == *"Aggregated throughput:"* ]]; then
			aggr_tput=$(echo "$line" | xargs | cut -d " " -f3)
		fi

		# if [[ "$line" == *"(FSYNC)LATENCY:"* ]]; then
		#         fsync_lat=$(echo "$line" | xargs | cut -d " " -f2)
		# fi
		# if [[ "$line" == *"(FSYNC)Throughput:"* ]]; then
		#         fsync_tput=$(echo "$line" | xargs | cut -d " " -f2)
		# fi
		# if [[ "$line" == *"(AGGREGATE)Throughput:"* ]]; then
		#         aggr_tput=$(echo "$line" | xargs | cut -d " " -f2)
		# fi

		# echo "aggr_tput=$aggr_tput"

	done < <(printf '%s\n' "$1")

	echo -n "$aggr_tput,"
	# echo "$fsync_lat,$fsync_tput,$aggr_tput"
}

if [ "$#" -ne 2 ]; then
	printUsage
	exit
fi

parseLog "$2"
