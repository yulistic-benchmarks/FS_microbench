#!/bin/bash
# Default configurations #################
BENCH_MICRO="./" # Set proper path.
DIRS="/mnt/ext4/ext4_journal /mnt/zj/zj_journal " # Basename is used as a bench run name. Use different name. Ex) /mnt/ext4/text_ext4 --> text_ext4 is name.
OPS="sw sr rw rr"
TOTAL_WRITE_SIZE=$((1024 * 1024 * 1024))
IO_SIZES="1K 4K 16K 64K 1M"
NUM_THREADS="1"
PROFILE_CPU_UTILIZATION=1
PINNING="numactl -N 1 -m 1"
##########################################

dropCache() {
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 10
}

### Microbench throughput
runMicroTput() {
	############# Overriding configurations
	DIRS="/mnt/zj/zj_ordered"
	OPS="rw"
	TOTAL_WRITE_SIZE=$((40 * 1024)) # in MB
	IO_SIZES="64K"
	NUM_THREADS="1 16 4 1"
	#######################################

	cd "$BENCH_MICRO" || exit

	# DIR_CNT=1
	for DIR in $DIRS; do
		for OP in $OPS; do
			for IO_SIZE in $IO_SIZES; do
				for NUM_THREAD in $NUM_THREADS; do
					# Set file size.
					FILE_SIZE=$(($TOTAL_WRITE_SIZE / $NUM_THREAD)) # Round down.

					# Set output file path.
					# OUT_DIR=./results/tput/dir${DIR_CNT}
					OUT_DIR=./results/tput/$(basename $DIR)
					OUT_FILE=$OUT_DIR/${OP}_${IO_SIZE}_${NUM_THREAD}t
					mkdir -p $OUT_DIR

					if [ -n $PROFILE_CPU_UTILIZATION ]; then
						OUT_CPU_FILE=${OUT_FILE}.cpu

						# Start to record CPU utilization with time stamps in background.
						top -b -d1 | awk '/tput_micro/ {print systime(), $0}' >$OUT_CPU_FILE &
					fi

					echo "Dropping cache."
					dropCache

					if [[ -n $OXBOW_PREFIX && $DIR == *"$OXBOW_PREFIX" ]]; then
						CMD="$PINNING $LIBFS/run.sh $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE $NUM_THREAD"
					else
						CMD="$PINNING $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE $NUM_THREAD"
					fi

					# Print command.
					echo Command: "$CMD" | tee ${OUT_FILE}.out

					# Execute
					$CMD | tee -a ${OUT_FILE}.out

					if [ -n $PROFILE_CPU_UTILIZATION ]; then
						# Kill top background process.
						sudo pkill -9 -x "top"
					fi
				done
			done
		done
		# ((DIR_CNT = DIR_CNT + 1))
	done
}

runMicroLat() {
	### Microbench latency
	### Overriding
	# DIRS="/oxbow ./"
	# OPS="sw sr rw rr"
	TOTAL_WRITE_SIZE="128M"
	# IO_SIZES="1K 4K 16K 64K 1M"
	# NUM_THREADS="1"

	cd "$BENCH_MICRO" || exit
	# DIR_CNT=1
	for DIR in $DIRS; do
		for OP in $OPS; do
			for IO_SIZE in $IO_SIZES; do

				FILE_SIZE=$TOTAL_WRITE_SIZE # There is only 1 thread.

				# Set output file path.
				# OUT_DIR=./results/lat/dir${DIR_CNT}
				OUT_DIR=./results/lat/$(basename $DIR)
				OUT_FILE=$OUT_DIR/${OP}_${IO_SIZE}
				mkdir -p $OUT_DIR

				echo "Dropping cache."
				dropCache

				if [[ -n $OXBOW_PREFIX && $DIR == *"$OXBOW_PREFIX" ]]; then
					CMD="$PINNING $LIBFS/run.sh $BENCH_MICRO/build/lat_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE 1"
				else
					CMD="$PINNING $BENCH_MICRO/build/lat_micro -d $DIR -s $OP ${FILE_SIZE}M $IO_SIZE 1"
				fi

				# Print command.
				echo Command: "$CMD" | tee $OUT_FILE

				# Execute
				$CMD | tee $OUT_FILE
			done
		done
		# ((DIR_CNT = DIR_CNT + 1))
	done
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	runMicroTput
	# runMicroLat
	echo "Output files are in 'results' directory."
fi
