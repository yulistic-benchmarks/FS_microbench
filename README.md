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

## Run

### Run all

```shell
# Configure the scripts.
scripts/run_all.sh
```

### Throughput micro benchmark

```shell
build/tput_micro -s sw 1G 4K 1
```

### Latency micro benchmark

```shell
build/lat_micro -s sw 256M 4K 1
```

## Parse results

### Parse all

```shell
scripts/parse_all.sh results
```

### Parse throughput output

For example, to print `sequential write` result:

```shell
scripts/parse_tput.sh sw "$(cat output.log)"
```

### Parse latency output

For example, to print `sequential write` result:

```shell
scripts/parse_lat.sh sw "$(cat output.log)"
```

## Development

- Recommended to use clang auto formatter of VSCode. There is a format file `.clang-format`.