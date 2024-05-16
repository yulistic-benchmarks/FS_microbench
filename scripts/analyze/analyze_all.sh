#!/bin/bash

OPS="dbal dbol dbom"
NUM_THREADS="1 2 4 8 16 32"

run()  {
    for OP in $OPS; do
        for NUM_THREAD in $NUM_THREADS; do
            echo "'${OP}'-'${NUM_THREAD}'"
            sudo ./analyze_tool.sh "${OP}" "${NUM_THREAD}"
        done
    done
}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	run
fi
