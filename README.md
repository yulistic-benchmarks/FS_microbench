# File system micro benchmark suite

## Dependency

```shell
sudo apt install -y meson pkg-config
```

## Build

```shell
rm -rf build
./build.sh
```

## Write a file system specific file.

Referring to `ext4_main.sh`, write another script for a new file system. You have to:

- set proper `DEV_PATH` and `TOTAL_JOURNAL_SIZE`
- set proper parameters (overriding `run_tput/lat_all.sh`)
- write a function, `runFileSystemSpecific`: A callback function called by the
  `run_tput/lat_all.sh` file. It dumps file system states and executes bench.
- write a function, `runBenchmark`: File system-specific preparations. Or,
  run with different options (i.e., journal option).

in your new script file.

## Run

### Run all

```shell
# Configure the scripts.

# In the project root directory,

# Run latency bench.
./scripts/ext4_main.sh -l

# Run throughput bench.
./scripts/ext4_main.sh -t
```

### (cf.) Run throughput micro benchmark (simple command)

```shell
build/tput_micro -s ap 1G 4K 1
```

### (cf.) Run latency micro benchmark (simple command)

```shell
build/lat_micro -s sw 256M 4K 1
```

## Parse results

### Parse all

```shell
# `results` is the basic directory where the output files are stored.
scripts/parse_all.sh results
```

### (cf.) Parse throughput output

For example, to print `sequential write` result:

```shell
scripts/parse_tput.sh sw "$(cat output.log)"
```

### (cf.) Parse latency output

For example, to print `sequential write` result:

```shell
scripts/parse_lat.sh sw "$(cat output.log)"
```

## Development

- Recommended to use clang auto formatter of VSCode. There is a format file `.clang-format`.
