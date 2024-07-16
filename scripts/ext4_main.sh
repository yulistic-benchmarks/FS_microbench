#!/bin/bash
source scripts/run_all.sh

############# Overriding configurations of run_tput_all.sh
# DIRS="/mnt/ext4/ext4_journal"
# DIRS="/mnt/ext4/ext4_ordered"
DIRS="./ext4_test"
OPS="sw"
# TOTAL_WRITE_SIZE=$((40 * 1024)) # in MB
TOTAL_WRITE_SIZE=$((4 * 1)) # in MB
# IO_SIZES="4K 16K 64K 1M"
IO_SIZES="4K"
# NUM_THREADS="1 16 4 1"
NUM_THREADS="1"


###### File system specific main function. Should be declared.

runFileSystemSpecific() {

	echo "It is Ext4-specific main."
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# fixCPUFreq

	loopMicroTput

	echo "Output files are in 'results' directory."
fi
