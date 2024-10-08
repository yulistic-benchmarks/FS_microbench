#!/bin/bash
# Default configurations #################
BENCH_MICRO="./"                                  # Set proper path.
DIRS="/mnt/ext4/ext4_journal /mnt/zj/zj_journal " # Basename is used as a bench run name. Use different name. Ex) /mnt/ext4/text_ext4 --> text_ext4 is name.
OPS="rw sw sr rr"                                 # Ex: "rw sw sr rr"
TOTAL_WRITE_SIZE=$((1024))                        # in MB
IO_SIZES="4K 16K 64K 1M"                          # Ex: "1K 4K 16K 64K 1M"
PROFILE_CPU_UTILIZATION=0
# PINNING=""
PINNING="numactl -N 1 -m 1"
# PINNING="numactl -N 0 -m 0"
# PERF_BIN="perf" # Set correct perf bin path.
PERF_BIN="/lib/modules/$(uname -r)/source/tools/perf/perf" # Set correct perf bin path.
##########################################

# Check perf bin.
if [ "$PROFILE_CPU_UTILIZATION" = "1" ]; then
	$PERF_BIN -h &>/dev/null || {
		echo "Set proper perf bin. Current setup:${PERF_BIN}"
		exit 1
	}
fi

dropCache() {
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 3
}

fixCPUFreq() {
	## Lock CPU frequency.
	sudo cpupower --cpu all frequency-set --freq 2300MHz # CONFIG Check the max freq with lscpu.
	if [ $? -ne 0 ]; then
		echo Locking CPU frequency failed. Check cpupower command.
		echo You can build it from linux source. Check tools/power/cpupower.
		exit 1
	fi
	sudo cpupower --cpu all frequency-info | grep "current CPU freq"
}

### Microbench latency
loopMicroLat() {

	for DIR in $DIRS; do
		for OP in $OPS; do
			for IO_SIZE in $IO_SIZES; do
				# Set file size.
				FILE_SIZE=$TOTAL_WRITE_SIZE # There is only 1 thread for latency measurement.

				# Set output file path.
				OUT_DIR="$BENCH_MICRO/results/lat/$(basename $DIR)"
				OUT_FILE="$OUT_DIR/${OP}_${IO_SIZE}"
				mkdir -p $OUT_DIR

				echo "Remove (re-create) existing files."
				if [ $OP = "sr" ] || [ $OP = "rr" ]; then
					# Remove the existing files and create them again. Otherwise, the file sizes might be different.
					rm -rf $DIR/*
					$PINNING $BENCH_MICRO/build/lat_micro -d $DIR -s sw ${FILE_SIZE}M $IO_SIZE 1
				else
					# Remove existing files. Otherwise, the file size might be different.
					rm -rf $DIR/*
				fi

				echo "Dropping cache."
				dropCache

				if [ "$PROFILE_CPU_UTILIZATION" = "1" ]; then
					# Use perf.
					OUT_CPU_FILE=${OUT_FILE}.perfdata
					PERF_PREFIX="sudo $PERF_BIN record -a -o $OUT_CPU_FILE --"
				else
					PERF_PREFIX=""
				fi

				# Print mount state.
				sudo mount >${OUT_FILE}.mount

				runFileSystemSpecific
			done
		done
	done
}

# Execute only this script is directly executed. (Not sourced)
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
# 	fixCPUFreq

# 	loopMicroLat
# 	echo "Output files are in 'results' directory."
# fi
