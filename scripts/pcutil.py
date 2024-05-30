# import psutil
# import time
# import datetime
# import sys
# import csv

# def record_and_print_specific_process_cpu_usage(filename):
#     process_cpu_usage = {}
#     log_entries = []
#     filter_processes = ['kworker/u', 'jbd2/nvme', 'tput_micro', 'zj/nvme'
#     ]
#     interval = 0.5  # Check every 0.5 seconds
#     aggregate_interval = 1  # Print every 1 second

#     try:
#         print("Recording CPU usage. Press Ctrl-C to stop.")
#         half_second_counts = int(aggregate_interval / interval)
#         while True:
#             # Initialize current usage tracking
#             current_cpu_usage = {}
#             for i in range(half_second_counts):
#                 # Get current time for timestamp
#                 if i == 0:
#                     timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
#                 for proc in psutil.process_iter(['name']):
#                     try:
#                         name = proc.info['name']
#                         if any(name.startswith(fp) for fp in filter_processes):
#                             cpu_usage = proc.cpu_percent(interval=None)  # Get CPU usage without interval
#                             if cpu_usage > 0:  # Only track processes that are actively using the CPU
#                                 if name in current_cpu_usage:
#                                     current_cpu_usage[name] += cpu_usage
#                                 else:
#                                     current_cpu_usage[name] = cpu_usage
#                     except (psutil.NoSuchProcess, psutil.AccessDenied):
#                         continue
                
#                 time.sleep(interval)
            
#             # Calculate the average CPU usage over the 1 second interval
#             for name in current_cpu_usage:
#                 current_cpu_usage[name] /= half_second_counts
#                 if name in process_cpu_usage:
#                     process_cpu_usage[name] += current_cpu_usage[name]
#                 else:
#                     process_cpu_usage[name] = current_cpu_usage[name]
            
#             # Print current CPU usage for each process
#             for name, cpu_usage in current_cpu_usage.items():
#                 #print(f"{timestamp} - {name}: {cpu_usage:.2f}%")
#                 log_entries.append((timestamp, name, cpu_usage))
            
#             #print("-" * 40)

#     except KeyboardInterrupt:
#         # Summation of average CPU usage
#         sorted_processes = sorted(process_cpu_usage.items(), key=lambda item: item[1], reverse=True)
#         print("\nSummation of CPU usage:")
#         for name, total_cpu_usage in sorted_processes:
#             print(f"{name}: {total_cpu_usage:.2f}%")

#         # Save to CSV file
#         with open(filename, "w", newline="") as f:
#             writer = csv.writer(f)
#             writer.writerow(["Timestamp", "Process_Name", "CPU_Usage"])
#             writer.writerows(log_entries)
#             writer.writerow([])
#             writer.writerow(["Process_Name", "Total_Avg_CPU_Usage"])
#             for name, total_cpu_usage in sorted_processes:
#                 writer.writerow([name, total_cpu_usage])

#         print(f"Data saved to {filename}")

# if __name__ == "__main__":
#     if len(sys.argv) != 2:
#         print("Usage: python script_name.py <output_filename>")
#     else:
#         record_and_print_specific_process_cpu_usage(sys.argv[1] + ".csv")


import psutil
import time
import datetime
import sys
import csv

def record_and_print_specific_process_cpu_usage(filename):
    process_cpu_usage = {}
    log_entries = []
    filter_processes = ['kworker/u', 'jbd2/nvme', 'tput_micro', 'zj/nvme']

    try:
        print("Recording CPU usage. Press Ctrl-C to stop.")
        while True:
            # Get current time for timestamp
            timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            # Update CPU usage for each process, storing by process name
            current_cpu_usage = {}
            for proc in psutil.process_iter(['name', 'cpu_percent']):
                try:
                    name = proc.info['name']
                    if any(name.startswith(fp) for fp in filter_processes):
                        cpu_usage = proc.info['cpu_percent']
                        if cpu_usage > 0:  # Only track processes that are actively using the CPU
                            if name in process_cpu_usage:
                                process_cpu_usage[name] += cpu_usage
                            else:
                                process_cpu_usage[name] = cpu_usage
                            current_cpu_usage[name] = cpu_usage
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

            # Print current CPU usage for each process
            for name, cpu_usage in current_cpu_usage.items():
                #print(f"{timestamp} - {name}: {cpu_usage:.2f}%")
                log_entries.append((timestamp, name, cpu_usage))

            time.sleep(1)
            #print("-" * 40)

    except KeyboardInterrupt:
        # Summation of CPU usage
        sorted_processes = sorted(process_cpu_usage.items(), key=lambda item: item[1], reverse=True)
        print("\nSummation of CPU usage:")
        for name, total_cpu_usage in sorted_processes:
            print(f"{name}: {total_cpu_usage:.2f}%")

        # Save to CSV file
        with open(filename, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["Timestamp", "Process_Name", "CPU_Usage"])
            writer.writerows(log_entries)
            writer.writerow([])
            writer.writerow(["Process_Name", "Total_CPU_Usage"])
            for name, total_cpu_usage in sorted_processes:
                writer.writerow([name, total_cpu_usage])

        print(f"Data saved to {filename}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script_name.py <output_filename>")
    else:
        record_and_print_specific_process_cpu_usage(sys.argv[1] + ".csv")
