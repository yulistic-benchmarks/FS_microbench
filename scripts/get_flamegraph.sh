#!/bin/bash
if [ -z $1 ]; then
	echo "Perf output file should be given."
	exit
fi
FLAMEGRAPH_DIR="../FlameGraph"
# Assuming perf output file is given as $1.
# Ex) sudo perf record -F 99 -a -g -- ./build/tput_micro -d /mnt/ext4/ext4_journal -s sw 40960M 64K 1

sudo perf script -i $1 >out.perf
$FLAMEGRAPH_DIR/stackcollapse-perf.pl out.perf >out.folded
$FLAMEGRAPH_DIR/flamegraph.pl out.folded >graph.svg
