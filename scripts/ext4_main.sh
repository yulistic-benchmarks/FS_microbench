#!/bin/bash
source scripts/run_tput_all.sh || { echo "Run in the project root directory."; exit 1;}

MOUNT_PATH="/mnt/ext4"

############# Overriding configurations of run_tput_all.sh
# DIRS="$MOUNT_PATH/ext4_journal"
DIRS="$MOUNT_PATH/ext4_ordered"
# OPS="sw"
# TOTAL_WRITE_SIZE=$((40 * 1024)) # in MB
# IO_SIZES="4K 16K 64K 1M"
# NUM_THREADS="1 4 16"


###### File system specific main function. Should be declared.
runFileSystemSpecific() {
	echo "Ext4 main function."

	CMD="$PERF_PREFIX $PINNING $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE $NUM_THREAD"

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}.out

	# Execute
	$CMD | tee -a ${OUT_FILE}.out
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# fixCPUFreq
	loopMicroTput
	echo "Output files are in 'results' directory."
fi
