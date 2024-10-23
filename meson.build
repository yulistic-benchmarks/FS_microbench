project('microbench', ['cpp', 'c'],
  version : '0.1',
  default_options : ['warning_level=3', 'buildtype=release', 'c_std=gnu99',
  'cpp_std=c++11'])

proj_root = meson.source_root()
build_root = meson.build_root()
current_dir = meson.current_source_dir()

# message('proj_root: ' + proj_root)
# message('build_root: ' + build_root)

cc = meson.get_compiler('cpp')
rt_dep = cc.find_library('rt', required : false)

### - *_inc : header files
### - *_lib : library
### - *_dep : dependencies (to library)

# CFS configuration
cfs_root_dir = run_command('sh', '-c', 'echo $CFS_ROOT_DIR').stdout().strip()

# Check if CFS_ROOT_DIR is set
if cfs_root_dir == ''
  error('CFS_ROOT_DIR environment variable is not set. Please set it to the path of your CFS installation.')
endif

cfs_include_dir = join_paths(cfs_root_dir, 'cfs/include')
tbb_include_dir = join_paths(cfs_root_dir, 'cfs/lib/tbb/include')
cfs_lib_dir = join_paths(cfs_root_dir, 'cfs/build')
tbb_lib_dir = join_paths(cfs_root_dir, 'cfs/lib/tbb/build/tbb_build_release')

# Add CFS and TBB include directories
cfs_includes = include_directories(cfs_include_dir)
tbb_includes = include_directories(tbb_include_dir)

# Find the CFS and TBB libraries
cfs_dep = declare_dependency(
  include_directories: cfs_includes,
  link_args: ['-L' + cfs_lib_dir, '-lcfs']
)

tbb_dep = declare_dependency(
  include_directories: tbb_includes,
  link_args: ['-L' + tbb_lib_dir, '-ltbb', '-ltbbmalloc']
)

# add_global_arguments('-DFLAG=value', language : 'c')

## Libfs source code headers.
inc = include_directories('include')
thread_dep = dependency('threads')

## Source files.
common_srcs = files(['src/thread.cc', 'src/time_stat.c'])

# tput_bench_srcs = files(['src/iobench.cc']) + common_srcs
tput_bench_srcs = files(['src/iobench.cc']) + common_srcs
lat_bench_srcs = files(['src/iobench_lat.cc']) + common_srcs

# Create the executables, now with CFS and TBB support
tput_exe = executable('tput_micro',
  tput_bench_srcs, 
  include_directories : [inc, cfs_includes, tbb_includes],  # Include CFS and TBB directories
  dependencies : [thread_dep, rt_dep, cfs_dep, tbb_dep],  # Add CFS and TBB dependencies
  c_args: ['-D_BSD_SOURCE'],
  cpp_args: ['-DUFS'])

lat_exe = executable('lat_micro',
  lat_bench_srcs, 
  include_directories : [inc, cfs_includes, tbb_includes],  # Include CFS and TBB directories
  dependencies : [thread_dep, rt_dep, cfs_dep, tbb_dep],  # Add CFS and TBB dependencies
  c_args: ['-D_BSD_SOURCE'],
  cpp_args: ['-DUFS'])