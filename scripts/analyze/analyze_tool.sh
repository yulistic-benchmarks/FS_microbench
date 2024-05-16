#!/bin/bash

# Check if workload and num are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <workload> <num>"
    exit 1
fi

workload=$1
num=$2
perf_data_file="${workload}-${num}-perf.data"
csv_file="${workload}-${num}.csv"

# Run the perf analysis script and capture the output
perf_output=$(./perf_anal.sh "$perf_data_file" 2>/dev/null)

# Extract the CPU usage percentage where the line starts with "journal functions occupy"
# Removing all trailing newline characters from the extracted value
cpu_usage_percent=$(echo "$perf_output" | grep '^journal functions occupy' | grep -o '[0-9]*\.[0-9]*' | awk '{print $1/100}' | tr -d '\n')

# echo "Debug: Raw percentage output: [$cpu_usage_percent]" # Debug output to check raw percentage

# Check if the cpu_usage_percent has been set or not
if [[ -z "$cpu_usage_percent" ]]; then
    echo "Error: Failed to extract CPU usage percent."
    exit 1
fi

# echo "Debug: CPU Usage Percent is [$cpu_usage_percent]" # Debug output

# Check the CSV file for the necessary data
if [ ! -f "$csv_file" ]; then
    echo "CSV file does not exist."
    exit 1
fi

# Initialize totals
total_cpu_usage_tput_micro=0
total_cpu_usage_jbd2_and_kworker=0
total_cpu_usage_others=0

# Process the CSV file
while IFS=, read -r timestamp total_cpu_usage process_name process_total_cpu_usage
do
    # Skip header
    if [[ "$process_name" == "Process_Name" ]]; then
        continue
    fi

    # Calculate scaled CPU usage for tput_micro
    if [[ "$process_name" == "tput_micro" ]]; then
        scaled_cpu_usage=$(echo "scale=2; $process_total_cpu_usage * $cpu_usage_percent" | bc)
        total_cpu_usage_tput_micro=$(echo "scale=2; $total_cpu_usage_tput_micro + $scaled_cpu_usage" | bc)
        # echo "Debug: Scaled CPU for tput_micro is $scaled_cpu_usage" # Debug output
    fi

    # Sum up CPU usage for jbd2* and kworker/u6*
    if [[ "$process_name" == jbd2* ]] || [[ "$process_name" == kworker/u6* ]]; then
        total_cpu_usage_jbd2_and_kworker=$(echo "scale=2; $total_cpu_usage_jbd2_and_kworker + $process_total_cpu_usage" | bc)
        # echo "Debug: Adding $process_total_cpu_usage for $process_name" # Debug output
    fi

    # Sum up CPU usage for all other processes
    total_cpu_usage_others=$(echo "scale=2; $total_cpu_usage_others + $process_total_cpu_usage" | bc)

done < "$csv_file"

# Print results with two decimal precision
printf "Foreground Journal (foregroundj): %.2f\n" $cpu_usage_percent
printf "Total CPU Usage (tput_micro): %.2f\n" $total_cpu_usage_tput_micro
printf "Total CPU Usage (jbd2 and kworker/u6): %.2f\n" $total_cpu_usage_jbd2_and_kworker
# printf "Total CPU Usage (All Others): %.2f\n" $total_cpu_usage_others
