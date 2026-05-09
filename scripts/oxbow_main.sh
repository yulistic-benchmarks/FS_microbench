#!/bin/bash
# Main function for FS_microbench.
# Assume that tmux session is ready as below.
# pane 0: Bench
# pane 1: Free
# pane 2: Secure Daemon
# pane 3: DevFS (Connected to SmartNIC via ssh & cd to the project root
# 	  directory & source set_env.sh)
#
set -xe

DEVICE_IP="192.168.14.114" # Set DevFS IP address. Need ssh access without password.

# Tmux pane numbers. Pane 1 is free.
BENCH_PANE="0"
SECURE_DAEMON_PANE="2"
DEVFS_PANE="3"

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
	# OPS="sw rw sr rr"
	OPS="ap sr rr rw" # ap should be the first. (checkpointing and mkfs order depend on it)
	DO_MKFS=1
	# TOTAL_WRITE_SIZE=$((20 * 1024)) # in MB
	PER_FILE_WRITE_SIZE=$((2 * 1024)) # in MB.
	IO_SIZES="4K 16K 64K 256K"
	# IO_SIZES="4K"
	NUM_THREADS="1 2 4 8 10 16"
	# NUM_THREADS="1"
	###############################################################################
else
	source scripts/run_lat_all.sh || {
		echo "Run in the project root directory."
		exit 1
	}

	############# Overriding configurations of run_lat_all.sh ####################
	# OPS="sw rw sr rr"
	OPS="sr rr"
	TOTAL_WRITE_SIZE=$((256)) # in MB
	IO_SIZES="1K 4K 16K 64K 256K 512K"
	# IO_SIZES="1K"
	###############################################################################
fi

MOUNT_PATH="$OXBOW_PREFIX"
DO_CHECKPOINT=1

# rm does not work with oxbow. Also, oxbow uses pre-generated file for read benchs.
RM_FILES=0 # Should be zero.

# Set total journal size.
# TOTAL_JOURNAL_SIZE=5120 # 5 GB
TOTAL_JOURNAL_SIZE=$((38 * 1024)) # 38 GB

initOxbow() {
	# Runninng Daemon as background
	sudo umount $OXBOW_PREFIX || true
	sleep 2

	tmux send-keys -t "$SECURE_DAEMON_PANE" "$SECURE_DAEMON/run.sh" C-m || true
	# $SECURE_DAEMON/run.sh -b  # Run in background. (deprecated)
	sleep 10

	# DAEMON_PID=$(pgrep "secure_daemon")
	# echo "[OXBOW_MICROBENCH] Daemon runnning PID: $DAEMON_PID"

	# TMP: No more mount.
	# sudo mount -t illufs dummy $OXBOW_PREFIX
	# echo "[OXBOW_MICROBENCH] mount oxbow FS\n"
	# sleep 5
}

killBgOxbow() {
	# Kill Daemon
	# echo "[OXBOW_MICROBENCH] Kill secure daemon($DAEMON_PID) and umount Oxbow."
	echo "[OXBOW_MICROBENCH] Kill secure daemon and umount Oxbow."
	$SECURE_DAEMON/run.sh -k || true
	sleep 3

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

	# Dump local devfs config. It may be different from the one on SmartNIC.
	if [ -e "${DEVFS}/myconf.sh" ]; then
		echo "$DEVFS/myconf.sh" >>${OUT_FILE}.fsconf
		cat $DEVFS/myconf.sh >>${OUT_FILE}.fsconf
	fi

	echo "$DEVFS/devfs_conf.sh:" >>${OUT_FILE}.fsconf
	cat $DEVFS/devfs_conf.sh >>${OUT_FILE}.fsconf
}

# Send remote checkpoint signal to DevFS.
checkpoint() {
	# Clear flag.
	# Make sure the file path is identical to the one in the source code.
	# The path is in the NFS mount point. So, it is set by devfs in the SmartNIC.
	sudo ${SCRIPTS}/exp_flag.sh create ${EXP_FLAG_DIR}/ckpt_done 0

	sig_nu=$(expr $(kill -l SIGRTMIN) + 1)
	cmd="sudo pkill -${sig_nu} devfs"
	ssh ${DEVICE_IP} $cmd || true

	# Wait for the flag is finished.
	sudo ${SCRIPTS}/exp_flag.sh ${EXP_FLAG_DIR}/ckpt_done 1

	## Timeout-based wait.
	# sleep 10
}

doMKFS() {
	sleep 3

	# mkfs.
	${SCRIPTS}/host/mkfs.sh

	# Kill existing devfs.
	ssh ${DEVICE_IP} "sudo pkill -9 devfs" || true
	sleep 3

	# Execute devfs on smartNIC.
	tmux send-keys -t "$DEVFS_PANE" "$DEVFS/run.sh" C-m || true

	# Using ssh. (deprecated)
	# # Kill existing devfs.
	# ssh ${DEVICE_IP} "sudo pkill -9 devfs" || true
	# sleep 3
	#
	# # Execute devfs on smartNIC.
	# ssh ${DEVICE_IP} "cd /home/yulistic/oxbow; source set_env.sh; /home/yulistic/oxbow/oxbow/devfs/run.sh > /tmp/devfs.out 2>&1 &" || true
	# sleep 3
	#
	# Set the nice value to 0. (deprecated)
	# ssh ${DEVICE_IP} "ps -eLf | grep build/devfs | awk '{print $4}' | xargs renice -n 0 -p" &> /dev/null || true
	# sleep 3
}

###### File system specific reset function. It is called before each benchmark run. Should be declared.
flushCache() {
	if [ "$DO_MKFS" -eq "1" ] && [ "$OP" = "ap" ]; then
		echo "Do MKFS."
		doMKFS
	fi

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
	# tmux send-keys -t "$BENCH_PANE" "$CMD | tee -a ${OUT_FILE}.out" C-m || true
	eval $CMD | tee -a ${OUT_FILE}.out

	# Do checkpoint.
	if [ "$DO_CHECKPOINT" -eq "1" ] && [ "$OP" = "ap" ]; then
		echo "Do Checkpoint."
		checkpoint
	fi
}

runBenchmark() {
	DIRS="$OXBOW_PREFIX" # Overriding config.

	# Umount if mounted.
	sudo umount $OXBOW_PREFIX || true

	# Kill all the Oxbow processes and microbench processes.
	$SECURE_DAEMON/run.sh -k || true
	sudo pkill -9 tput_micro || true
	sudo pkill -9 lat_micro || true
	sleep 2

	# Configure and mount file system.
	sudo chown -R $USER:$USER $MOUNT_PATH
	mkdir -p $DIRS

	if [ "$BENCHMARK_TYPE" = "throughput" ]; then
		loopMicroTput
	else
		loopMicroLat
	fi

	sleep 5
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
