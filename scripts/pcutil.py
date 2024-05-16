import psutil
import time
import datetime
import sys

def record_process_cpu_usage_until_interrupt(filename):
    total_cpu_usage = 0
    process_cpu_usage = {}

    try:
        print("Recording CPU usage. Press Ctrl-C to stop and save.")
        while True:
            # System-wide CPU percent for the interval
            total_cpu_usage += psutil.cpu_percent(interval=1)
            
            # Update CPU usage for each process, storing by process name
            for proc in psutil.process_iter(['name', 'cpu_percent']):
                try:
                    name = proc.info['name']
                    cpu_usage = proc.info['cpu_percent']
                    if cpu_usage > 0:  # Only track processes that are actively using the CPU
                        if name in process_cpu_usage:
                            process_cpu_usage[name] += cpu_usage
                        else:
                            process_cpu_usage[name] = cpu_usage
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

    except KeyboardInterrupt:
        # Sort the processes by CPU usage and keep only the top 10
        top_processes = sorted(process_cpu_usage.items(), key=lambda item: item[1], reverse=True)[:10]
        
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        # Writing results to a CSV file
        with open(filename, "w") as f:
            f.write("Timestamp,Total_CPU_Usage,Process_Name,Process_Total_CPU_Usage\n")
            for name, cpu_usage in top_processes:
                f.write(f"{timestamp},{total_cpu_usage},{name},{cpu_usage}\n")
        print(f"Data saved to {filename}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script_name.py <output_filename>")
    else:
        record_process_cpu_usage_until_interrupt(sys.argv[1]+".csv")