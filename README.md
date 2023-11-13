# File system micro benchmark suite

## Dependency

```shell
sudo apt install -y meson
```

## Build

```shell
rm -rf build
./build.sh
```

## Run

### Throughput micro benchmark

```shell
build/tput_micro -s sw 1G 4K 1
```

### Latency micro benchmark

```shell
build/lat_micro -s sw 256M 4K 1
```

## Development

- Recommended to use clang auto formatter of VSCode. There is a format file `.clang-format`.