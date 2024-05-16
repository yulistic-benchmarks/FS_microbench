#!/bin/bash
set -m
# PINNING="numactl -N 0 -m 0"

DIR="/tmp/ext4"
IO_SIZE="4K"
#OPS="dbal"
OPS="dbal dbol dbom"
#NUM_THREADS="4"
NUM_THREADS="1 2 4 8 16 32"
FILE_SIZE="32"

dropCache() {
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 10
}

run() {
	############# Overriding configurations
    OUT_FILE="cpu_test"
    OUT_DIR=./results/cpu
	#######################################

    for OP in $OPS; do
        for NUM_THREAD in $NUM_THREADS; do

            TEST_NAME="${OP}-${NUM_THREAD}"
            FILE_SIZE=$((32/NUM_THREAD))
            FILE_SIZE="${FILE_SIZE}G"
            echo File_size $FILE_SIZE

            PRE_OP="pre-${OP}"
            CMD="$PINNING $BENCH_MICRO/build/tput_micro -d $DIR $PRE_OP ${FILE_SIZE} $IO_SIZE $NUM_THREAD"
            echo Command: "$CMD"
            $CMD

            python3 pcutil.py "${OUT_DIR}/${TEST_NAME}" &
            perf_pid=$!
            sudo renice -n 0 -p $perf_pid

            CMD="$PINNING $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE} $IO_SIZE $NUM_THREAD"
            echo Command: "$CMD"
            sudo perf record -o "${OUT_DIR}/${TEST_NAME}-perf.data" -F 99 -e cycles -g -- $CMD
            # sudo perf record -o "${OUT_DIR}/${TEST_NAME}-perf.data" -F 99 -g -- $CMD
            #$CMD

            ## Wait until background done
            sleep 20

            echo "Force checkpoint"
            sudo $BENCH_MICRO/build/ext4_force_bg $DIR

            sleep 10
            
            sudo kill -2 $perf_pid

            CL_OP="cl-${OP}"
            CMD="$PINNING $BENCH_MICRO/build/tput_micro -d $DIR $CL_OP ${FILE_SIZE} $IO_SIZE $NUM_THREAD"
            echo Command: "$CMD"
            $CMD

            echo "Dropping cache."
	        dropCache
        done
    done

    # ## pidstat attach to background journaling thread
    # #pidstat -t -p $(pgrep jbd2/nvme2n1-8 ) 1 -u > $OUT_DIR/jbd2_cpu_usage.txt &
    # #jbd2_pidstat_pid=$!
    # #sudo renice -n 0 -p $jbd2_pidstat_pid
    
    # ## start microbenchmark
    # CMD="$PINNING $BENCH_MICRO/build/tput_micro -d $DIR -s $OP ${FILE_SIZE} $IO_SIZE $NUM_THREAD"
    # echo Command: "$CMD"
    # # sudo perf record -F 99 -g -- $CMD &
    # $CMD &
    # perf_pid=$!
    # sudo renice -n 0 -p $perf_pid

    # pidstat -t -p $perf_pid 1 | awk '$3 != "-"' > $OUT_DIR/bench_cpu_usage.txt &
    # micro_pidstat_pid=$!
    # sudo renice -n 0 -p $micro_pidstat_pid

    # ## bring it to foreground
    # jobs
    # fg %2

    # sudo kill -2 $micro_pidstat_pid

    # ## Wait until background done
    # sleep 20

    # echo "Force checkpoint"
    # sudo $BENCH_MICRO/build/ext4_force_bg $DIR

    # sleep 10

    # sudo kill -2 $jbd2_pidstat_pid

	# echo "Dropping cache."
	# dropCache
}


# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	run
	echo "Output files are in 'results' directory."
fi
