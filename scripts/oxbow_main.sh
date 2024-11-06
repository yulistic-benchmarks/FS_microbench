#!/bin/bash
# Main function for FS_microbench.
set -ex

if [ -z "$OXBOW_ENV_SOURCED" ]; then
	echo "Do source set_env.sh first."
	exit
fi

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
	OPS="sw rw sr rr"
	TOTAL_WRITE_SIZE=$((30 * 1024)) # in MB
	IO_SIZES="4K 16K 64K 1M"
	NUM_THREADS="1 2 4 8 16"
	###############################################################################
else
	source scripts/run_lat_all.sh || {
		echo "Run in the project root directory."
		exit 1
	}

	############# Overriding configurations of run_lat_all.sh ####################
	OPS="sw rw sr rr"
	TOTAL_WRITE_SIZE=$((1024)) # in MB
	IO_SIZES="4K 16K 64K 1M"
	###############################################################################
fi

MOUNT_PATH="$OXBOW_PREFIX"

# Set total journal size.
# TOTAL_JOURNAL_SIZE=5120 # 5 GB
TOTAL_JOURNAL_SIZE=$((38 * 1024)) # 38 GB

initOxbow() {
	# Runninng Daemon as background
	$SECURE_DAEMON/run.sh -b
	sleep 10
	DAEMON_PID=$(pgrep "secure_daemon")
	echo "[OXBOW_MICROBENCH] Daemon runnning PID: $DAEMON_PID"

	sudo mount -t illufs dummy $OXBOW_PREFIX
	echo "[OXBOW_MICROBENCH] mount oxbow FS\n"
	sleep 5
}

killBgOxbow() {
	# Kill Daemon
	echo "[OXBOW_MICROBENCH] Kill secure daemon($DAEMON_PID) and umount Oxbow."
	$SECURE_DAEMON/run.sh -k
	sleep 5

	# sudo kill -9 $DAEMON_PID
	# echo "[OXBOW_MICROBENCH] Exit secure daemon $DAEMON_PID"
	# sleep 5

	# sudo umount $OXBOW_PREFIX
	# echo "[OXBOW_MICROBENCH] umount oxbow FS\n"
	# sleep 5

}

dumpOxbowConfig() {
	if [ -e "${LIBFS}/myconf.sh" ]; then
		echo "$LIBFS/myconf.sh:" >${OUT_FILE}.fsconf
		cat $LIBFS/libfs_conf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$LIBFS/libfs_conf.sh:" >>${OUT_FILE}.fsconf
	cat $LIBFS/libfs_conf.sh >>${OUT_FILE}.fsconf

	if [ -e "${SECURE_DAEMON}/myconf.sh" ]; then
		echo "$SECURE_DAEMON/myconf.sh" >>${OUT_FILE}.fsconf
		cat $SECURE_DAEMON/myconf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$SECURE_DAEMON/secure_daemon_conf.sh:" >>${OUT_FILE}.fsconf
	cat $SECURE_DAEMON/secure_daemon_conf.sh >>${OUT_FILE}.fsconf

	if [ -e "${DEVFS}/myconf.sh" ]; then
		echo "$DEVFS/myconf.sh" >>${OUT_FILE}.fsconf
		cat $DEVFS/myconf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$DEVFS/devfs_conf.sh:" >>${OUT_FILE}.fsconf
	cat $DEVFS/devfs_conf.sh >>${OUT_FILE}.fsconf
}

###### File system specific reset function. It is called before each benchmark run. Should be declared.
flushCache() {
	dropCache
	killBgOxbow
	initOxbow
}

###### File system specific main function. Should be declared.
runFileSystemSpecific() {
	echo "Oxbow main function."

	dumpOxbowConfig

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		CMD="$PERF_PREFIX $PINNING $LIBFS/run.sh $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE $NUM_THREAD $PERF_SUFFIX"
	else
		CMD="$PERF_PREFIX $PINNING $LIBFS/run.sh $BENCH_MICRO/build/lat_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE 1 $PERF_SUFFIX"
	fi

	# Print command.
	echo Command: "$CMD" | tee ${OUT_FILE}.out

	# Execute
	eval $CMD | tee -a ${OUT_FILE}.out
}

runBenchmark() {
	DIRS="$OXBOW_PREFIX" # Overriding config.

	# Umount if mounted.
	sudo umount $OXBOW_PREFIX || true

	# Kill all the Oxbow processes and microbench processes.
	$SECURE_DAEMON/run.sh -k || true
	sudo pkill -9 tput_micro || true
	sudo pkill -9 lat_micro || true
	sleep 3


	initOxbow

	# Configure and mount file system.
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIRS

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		loopMicroTput
	else
		loopMicroLat
	fi

	killBgOxbow
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
