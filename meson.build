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


# add_global_arguments('-DFLAG=value', language : 'c')
# add_project_link_arguments('-lcfs -ltbb -ltbbmalloc', language: 'c')

## Libfs source code headers.
inc = include_directories('include')
inc_ufs = include_directories('/home/ahn9807/uFS/cfs/include')
thread_dep = dependency('threads')

## Source files.
common_srcs = files(['src/thread.cc', 'src/time_stat.c'])

# tput_bench_srcs = files(['src/iobench.cc']) + common_srcs
tput_bench_srcs = files(['src/iobench.cc']) + common_srcs
lat_bench_srcs = files(['src/iobench_lat.cc']) + common_srcs

tput_exe = executable('tput_micro',
tput_bench_srcs, include_directories : [inc, inc_ufs], dependencies : [thread_dep, rt_dep], c_args: ['-D_BSD_SOURCE'], link_args: ['-L/home/ahn9807/uFS/cfs/build/', '-lcfs', '-L/home/ahn9807/uFS/cfs/lib/tbb/build/tbb_build_release/', '-ltbb', '-ltbbmalloc'])

lat_exe = executable('lat_micro',
lat_bench_srcs, include_directories : [inc, inc_ufs], dependencies : [thread_dep, rt_dep], c_args: ['-D_BSD_SOURCE'], link_args: ['-L/home/ahn9807/uFS/cfs/build/', '-lcfs', '-L/home/ahn9807/uFS/cfs/lib/tbb/build/tbb_build_release/', '-ltbb', '-ltbbmalloc'])

#mkfs_srcs = ['src/mkfs/mkfs.c', 'lib/log.c/src/log.c']
#mkfs_exe = executable('mkfs',
#                      mkfs_srcs,
#                      include_directories : [inc, common_inc, log_inc, spdk_inc],
#                      dependencies : [spdk_nvme_dep, spdk_env_dpdk_dep, spdk_vmd_dep], # Shared library
#                      override_options: ['b_asneeded=false'], # Required for SPDK shared library.
#                      c_args: ['-DLOG_USE_COLOR'], # Print with color by log.c library.
#                      # dependencies : [spdk_nvme_dd.as_link_whole()], # Static library
#                      )

# subdir('test')
