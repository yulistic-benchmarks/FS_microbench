#!/bin/bash
# Main function for FS_microbench.
# set -ex
source scripts/common.sh

# Parse command line options
while getopts "lt" opt; do
	case ${opt} in
	l)
		BENCHMARK_TYPE="latency"
		;;
	t)
		BENCHMARK_TYPE="throughput"
		;;
	\?)
		echo "Usage: $0 [-l] [-t]"
		echo "  -l: Run latency benchmark"
		echo "  -t: Run throughput benchmark"
		exit 1
		;;
	esac
done

if [ "$BENCHMARK_TYPE" = "throughput" ]; then
	source scripts/run_tput_all.sh || {
		echo "Run in the project root directory."
		exit 1
	}

	############# Overriding configurations of run_tput_all.sh ####################
	OPS="sr rr"
	TOTAL_WRITE_SIZE=$((20 * 1024)) # in MB
	# PER_FILE_WRITE_SIZE=$((2 * 1024)) # in MB
	IO_SIZES="4K 16K 64K 256K"
	NUM_THREADS="1 2 4 8 16"
	# NUMA="1"
	# CPU_MASK="16-31"
	PINNING=""
	###############################################################################
else
	source scripts/run_lat_all.sh || {
		echo "Run in the project root directory."
		exit 1
	}

	############# Overriding configurations of run_lat_all.sh ####################
	OPS="sw rw sr rr"
	TOTAL_WRITE_SIZE=$((256)) # in MB
	IO_SIZES="1K 4K 16K 64K 256K 512K"
	NUMA="1"
	CPU_MASK="16-31"
	PINNING=""
	###############################################################################
fi

MOUNT_PATH="/mnt/ext4"

# Set nvme device path.
# DEV_PATH="/dev/nvme2n1"
#
# Or, get it automatically. nvme-cli is required. (sudo apt install nvme-cli)
DEV_PATH="$(sudo nvme list | grep "SAMSUNG MZPLJ3T2HBJR-00007" | xargs | cut -d " " -f 1)"
echo Device path: "$DEV_PATH"

# Set total journal size.
# TOTAL_JOURNAL_SIZE=5120 # 5 GB
TOTAL_JOURNAL_SIZE=$((38 * 1024)) # 38 GB
TOTAL_INODE_NUM=6104832 # To reduce mkfs time. Set proper value.

umountFS() {
	sudo umount $MOUNT_PATH || true
}

###### File system specific reset function. It is called before each benchmark run.
flushCache() {
	dropCache
}

###### File system specific main function. Should be declared.
runFileSystemSpecific() {
	echo "Ext4 main function."

	# dump file system configs.
	sudo dumpe2fs -h $DEV_PATH >${OUT_FILE}.fsconf

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		CMD="$PERF_PREFIX $PINNING $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE $NUM_THREAD $PERF_SUFFIX"
	else
		CMD="$PERF_PREFIX $PINNING $BENCH_MICRO/build/lat_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE 1 $PERF_SUFFIX"
	fi

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}.out

	# Execute
	eval $CMD | tee -a ${OUT_FILE}.out
}

runBenchmark() {
	umountFS

	### Run data=journal mode
	DIRS="$MOUNT_PATH/ext4_journal" # Overriding config.

	# Configure and mount file system.
	sudo mke2fs -t ext4 -J size=$TOTAL_JOURNAL_SIZE -E lazy_itable_init=0,lazy_journal_init=0 -N $TOTAL_INODE_NUM -F -G 1 $DEV_PATH
	sudo mount -t ext4 -o barrier=0,data=journal $DEV_PATH $MOUNT_PATH
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIRS

	# NUMA binding:
	if [ -n ${CPU_MASK} ]; then
		jbd_pid=$(ps aux | grep jbd2 | grep $(basename $DEV_PATH) | xargs | cut -d ' ' -f2)
		sudo taskset -cp $CPU_MASK $jbd_pid
		echo "Binding jbd2 process($jbd_pid) to NUMA ${NUMA}. Taskset result:"
		sudo taskset -p $jbd_pid
	fi

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		loopMicroTput
	else
		loopMicroLat
	fi

	umountFS

	# Run data=ordered mode
	DIRS="$MOUNT_PATH/ext4_ordered" # Overriding config.
	sudo mke2fs -t ext4 -J size=$TOTAL_JOURNAL_SIZE -E lazy_itable_init=0,lazy_journal_init=0 -N $TOTAL_INODE_NUM -F -G 1 $DEV_PATH
	sudo mount -t ext4 -o barrier=0 $DEV_PATH $MOUNT_PATH
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIRS

	# NUMA binding:
	jbd_pid=$(ps aux | grep jbd2 | grep $(basename $DEV_PATH) | xargs | cut -d ' ' -f2)
	sudo taskset -cp $CPU_MASK $jbd_pid
	echo "Binding jbd2 process($jbd_pid) to NUMA ${NUMA}. Taskset result:"
	sudo taskset -p $jbd_pid

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		loopMicroTput
	else
		loopMicroLat
	fi

	umountFS
}

# Execute only if this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	if [ -z "$BENCHMARK_TYPE" ]; then
		echo "Please specify either -l for latency or -t for throughput benchmark."
		exit 1
	fi

	# fixCPUFreq

	runBenchmark

	echo "Output files are in 'results' directory."
fi
