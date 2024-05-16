#!/bin/bash

# Check if a file name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_perf.data>"
    exit 1
fi

PERF_DATA_FILE=$1

# Generate perf script output using the provided perf.data file
perf script -i "$PERF_DATA_FILE" > perf_script_output.txt

# Calculate total execution cycles and the cycles for events involving journal related functions
awk '
BEGIN { total_cycles = 0; journal_cycles = 0; }

# Capture the total cycles for each event
/^[[:alnum:]_]+[[:space:]][[:digit:]]+[[:space:]]+([[:digit:]]+\.[[:digit:]]+):[[:space:]]+([[:digit:]]+)[[:space:]]cycles:/ {
    current_cycles = $2;
    total_cycles += current_cycles;
    journal_event = 0;
}

# Check for lines containing 'journal' to flag the event
# Not use only journal, it will contain ext4 function
/journal_|jbd2/ {
    journal_event = 1;
}

# At the end of each event, if it involved an journal function, add its cycles to journal_cycles
/^$/ {
    if (journal_event) {
        journal_cycles += current_cycles;
    }
}

END {
    if (total_cycles > 0) {
        percentage = journal_cycles / total_cycles * 100;
        printf "journal functions occupy %.2f%% of total CPU cycles.\n", percentage;
    } else {
        print "No valid total cycles calculated (total cycles is zero).";
    }
}
' perf_script_output.txt

# Clean up
rm perf_script_output.txt