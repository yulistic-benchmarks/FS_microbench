#include <assert.h>
#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <iostream>
#include <linux/limits.h>
#include <list>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <vector>
#include <time.h>

#include "thread.h"
#include "time_stat.h"

const char *test_dir_prefix = "./pmem";
char *test_file_name = "testfile";

#define ALIGN_MASK(x, mask) (((x) + (mask)) & ~(mask))
#define ALIGN_MASK_FLOOR(x, mask) (((x)) & ~(mask))
#define ALIGN(x, a) ALIGN_MASK((x), ((__typeof__(x))(a)-1))
#define ALIGN_FLOOR(x, a) ALIGN_MASK_FLOOR((x), ((__typeof__(x))(a)-1))
#define BUF_SIZE (2 << 20)

// #define ODIRECT
#undef ODIRECT
// #define VERIFY

char fxmark_dbal_name[NAME_MAX] = "data_blk_append_low";
char fxmark_dbol_name[NAME_MAX] = "data_blk_overwrite_low";
char fxmark_dbom_name[NAME_MAX] = "data_blk_overwrite_med";

char data_block[4096] = { 1 };

typedef enum {
	SEQ_WRITE,
	SEQ_READ,
	SEQ_WRITE_READ,
	RAND_WRITE,
	RAND_READ,
	ZIPF_WRITE,
	ZIPF_READ,
	ZIPF_MIX,

	/* Following are from FXMARK workload. Refer the paper. */
	FXMARK_DBAL, // data block append low
	FXMARK_DBOL, // data block overwrite low
	FXMARK_DBOM, // data block overwrite medium

	PREPARE_DBAL,
	PREPARE_DBOL,
	PREPARE_DBOM,

	CLEAN_DBAL,
	CLEAN_DBOL,
	CLEAN_DBOM,

	NONE
} test_t;

typedef enum { FS } test_mode_t;

typedef unsigned long addr_t;

static pthread_barrier_t tsync;
uint8_t dev_id;
unsigned long ops_cap;
int psync; // process barrier
int do_fsync;
// static unsigned int *shm_proc_inf; // Keep running infinitely.

class io_bench : public CThread {
    public:
	io_bench(int _id, unsigned long _file_size_bytes, unsigned int _io_size,
		 test_t _test_type);

	int id, fd, per_thread_stats;
	unsigned long file_size_bytes;
	unsigned int io_size;
	test_t test_type;
	string test_file;
	string zipf_file;
	char *buf;
	struct time_stats stats;

	std::list<uint64_t> io_list;
	std::list<uint8_t> op_list;

	pthread_cond_t cv;
	pthread_mutex_t cv_mutex;

	void prepare(void);
	void cleanup(void);

	void do_prepare(void);
	void do_read(void);
	void do_write(void);
	void do_clean(void);

	// Thread entry point.
	void Run(void);

	// util methods
	static unsigned long str_to_size(char *str);
	static test_t get_test_type(char *);
	static test_mode_t get_test_mode(char *);
	static void hexdump(void *mem, unsigned int len);
	static void show_usage(const char *prog);
};

io_bench::io_bench(int _id, unsigned long _file_size_bytes,
		   unsigned int _io_size, test_t _test_type)
	: id(_id), file_size_bytes(_file_size_bytes), io_size(_io_size),
	  test_type(_test_type)
{
	test_file.assign(test_dir_prefix);

	if (test_type == FXMARK_DBAL || test_type == PREPARE_DBAL ||
	    test_type == CLEAN_DBAL) {
		test_file += "/" + std::string(fxmark_dbal_name) + "-" +
			     std::to_string(id);
	}

	if (test_type == FXMARK_DBOL || test_type == PREPARE_DBOL ||
	    test_type == CLEAN_DBOL) {
		test_file += "/" + std::string(fxmark_dbol_name) + "-" +
			     std::to_string(id);
	}

	if (test_type == FXMARK_DBOM || test_type == PREPARE_DBOM ||
	    test_type == CLEAN_DBOM) {
		test_file += "/" + std::string(fxmark_dbom_name);
	}

	// std::cout << "File name is " << test_file << std::endl;
}

void io_bench::prepare(void)
{
	pthread_mutex_init(&cv_mutex, NULL);
	pthread_cond_init(&cv, NULL);

	if (test_type == FXMARK_DBAL || test_type == FXMARK_DBOL ||
	    test_type == FXMARK_DBOM) {
		fd = open(test_file.c_str(), O_RDWR);
		if (fd < 0) {
			err(1, "file not exist!");
			exit(-1);
		}
	}
}

const int cnt_max = 3;
void io_bench::do_write(void)
{
	int bytes_written;
	// unsigned long random_range;
	uint32_t count = 0;

	// random_range = file_size_bytes / io_size;

	// cout << "# of ops: " << ops_cap << endl;

	if (test_type == FXMARK_DBAL || test_type == FXMARK_DBOL) {
		unsigned int _io_size = io_size;

		for (unsigned long i = 0; i < file_size_bytes; i += io_size) {
			count++;
			if (i + io_size > file_size_bytes)
				_io_size = file_size_bytes - i;
			else
				_io_size = io_size;

			bytes_written = write(fd, data_block, _io_size);

			if (bytes_written != io_size) {
				printf("write request %u received len %d\n",
				       _io_size, bytes_written);
				errx(1, "write");
			}

			if (count >= ops_cap) {
				// cout << "write done." << endl;
				count = 0;
				break;
			}
		}
	} else if (test_type == FXMARK_DBOM) {
		unsigned int _io_size = io_size;
		off_t ofs = id * file_size_bytes;

		// printf("[%d] offset start %ld\n", id, ofs);

		for (unsigned long i = 0; i < file_size_bytes; i += io_size) {
			count++;
			if (i + io_size > file_size_bytes)
				_io_size = file_size_bytes - i;
			else
				_io_size = io_size;

			bytes_written =
				pwrite(fd, data_block, _io_size, ofs + i);

			if (bytes_written != io_size) {
				printf("write request %u received len %d\n",
				       _io_size, bytes_written);
				errx(1, "write");
			}

			if (count >= ops_cap) {
				// cout << "write done." << endl;
				// printf("[%d] offset end %ld\n", id, ofs + i);
				count = 0;
				break;
			}
		}
	}

	else {
		printf("Not supported test!\n");
		exit(-1);
	}

	time_t current_time;
	struct tm *time_info;
	char time_string[20];

	time(&current_time);
	time_info = localtime(&current_time);
	strftime(time_string, sizeof(time_string), "%Y-%m-%d %H:%M:%S",
		 time_info);

	printf("%s thread(%d) done\n", time_string, id);

	return;
}

void io_bench::do_read(void)
{
	perror("no read in this test");
	exit(-1);
}

void io_bench::do_clean(void)
{
	if (unlink(test_file.c_str()) < 0) {
		perror("unlink fail");
		exit(-1);
	}
	sync();
}

void io_bench::do_prepare(void)
{
	if (!(test_type == PREPARE_DBAL || test_type == PREPARE_DBOL ||
	      test_type == PREPARE_DBOM)) {
		err(1, "no such case");
		exit(-1);
	}

	/* Create a file */
	fd = open(test_file.c_str(), O_RDWR | O_CREAT,
		  S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
	if (fd < 0) {
		err(1, "Failed to create");
		exit(-1);
	}

	/* Make a file being written first */
	if (test_type == PREPARE_DBOL || test_type == PREPARE_DBOM) {
		int bytes_written;
		uint32_t count = 0;
		unsigned int _io_size = io_size;

		for (unsigned long i = 0; i < file_size_bytes; i += io_size) {
			count++;
			if (i + io_size > file_size_bytes)
				_io_size = file_size_bytes - i;
			else
				_io_size = io_size;

			bytes_written = write(fd, data_block, _io_size);

			if (bytes_written != io_size) {
				printf("write request %u received len %d\n",
				       _io_size, bytes_written);
				errx(1, "write");
			}

			if (count >= ops_cap) {
				cout << id << " prepared for overwrite" << endl;
				count = 0;
				break;
			}
		}
	}

	fsync(fd);
	sync();

	/* Check file size is right or not */
	struct stat statbuf;
	size_t file_size;

	if (fstat(fd, &statbuf) == -1) {
		perror("Failed to get file size");
		exit(-1);
	}

	file_size = statbuf.st_size;
	if (test_type == PREPARE_DBAL) {
		if (file_size != 0) {
			perror("file should be zero size");
			exit(-1);
		}
	}

	if (test_type == PREPARE_DBOL || test_type == PREPARE_DBOM) {
		if (file_size != file_size_bytes) {
			perror("file size wrong");
			exit(-1);
		}
	}
}

void io_bench::Run(void)
{
	time_t current_time;
	struct tm *time_info;
	char time_string[20];

	time(&current_time);
	time_info = localtime(&current_time);
	strftime(time_string, sizeof(time_string), "%Y-%m-%d %H:%M:%S",
		 time_info);

	printf("%s thread(%d) start\n", time_string, id);

	if (test_type == PREPARE_DBAL || test_type == PREPARE_DBOL ||
	    test_type == PREPARE_DBOM)
		this->do_prepare();
	else if (test_type == CLEAN_DBAL || test_type == CLEAN_DBOL ||
		 test_type == CLEAN_DBOM)
		this->do_clean();
	else
		this->do_write();

	pthread_mutex_unlock(&cv_mutex);

	return;
}

void io_bench::cleanup(void)
{
	if (test_type == FXMARK_DBAL || test_type == FXMARK_DBOL ||
	    test_type == FXMARK_DBOM)
		close(fd);
}

unsigned long io_bench::str_to_size(char *str)
{
	/* magnitude is last character of size */
	char size_magnitude = str[strlen(str) - 1];
	/* erase magnitude char */
	str[strlen(str) - 1] = 0;
	unsigned long file_size_bytes = strtoull(str, NULL, 0);
	switch (size_magnitude) {
	case 'g':
	case 'G':
		file_size_bytes *= 1024;
	case 'm':
	case 'M':
		file_size_bytes *= 1024;
	case '\0':
	case 'k':
	case 'K':
		file_size_bytes *= 1024;
		break;
	case 'p':
	case 'P':
		file_size_bytes *= 4;
		break;
	case 'b':
	case 'B':
		break;
	default:
		std::cout << "incorrect size format " << str << endl;
		break;
	}
	return file_size_bytes;
}

test_t io_bench::get_test_type(char *test_type)
{
	/**
   * Check the mode to bench: read or write and type
   */
	if (!strcmp(test_type, "dbol")) {
		return FXMARK_DBOL;
	} else if (!strcmp(test_type, "dbom")) {
		return FXMARK_DBOM;
	} else if (!strcmp(test_type, "dbal")) {
		return FXMARK_DBAL;
	} else if (!strcmp(test_type, "pre-dbol")) {
		return PREPARE_DBOL;
	} else if (!strcmp(test_type, "pre-dbom")) {
		return PREPARE_DBOM;
	} else if (!strcmp(test_type, "pre-dbal")) {
		return PREPARE_DBAL;
	} else if (!strcmp(test_type, "cl-dbol")) {
		return CLEAN_DBOL;
	} else if (!strcmp(test_type, "cl-dbom")) {
		return CLEAN_DBOM;
	} else if (!strcmp(test_type, "cl-dbal")) {
		return CLEAN_DBAL;
	} else {
		show_usage("tput_micro");
		cerr << "unsupported test type" << test_type << endl;
		exit(-1);
	}
}

#define HEXDUMP_COLS 8
void io_bench::hexdump(void *mem, unsigned int len)
{
	return;
}

void io_bench::show_usage(const char *prog)
{
	std::cerr
		<< "usage: " << prog
		<< " [-d <directory>] [-f <file-prefix>] [-n <# of ops>] [-s "
		   "'fsync'] <dbol, dbom, dbal, pre-*, cl-*>"
		<< " <size: X{G,M,K,P}, eg: 100M> <IO size, e.g.: 4K> <# of thread>"
		<< endl;
}

/* Returns new argc */
static int adjust_args(int i, char *argv[], int argc, unsigned del)
{
	if (i >= 0) {
		for (int j = i + del; j < argc; j++, i++)
			argv[i] = argv[j];
		argv[i] = NULL;
		return argc - del;
	}
	return argc;
}

int process_opt_args(int argc, char *argv[])
{
	int dash_d = -1;
restart:
	for (int i = 0; i < argc; i++) {
		// printf("argv[%d] = %s\n", i, argv[i]);
		if (strncmp("-d", argv[i], 2) == 0) {
			test_dir_prefix = argv[i + 1];
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 2);
			goto restart;
		} else if (strncmp("-n", argv[i], 2) == 0) {
			ops_cap = strtoull(argv[i + 1], NULL, 0);
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 2);
			goto restart;
		} else if (strncmp("-f", argv[i], 2) == 0) {
			test_file_name = argv[i + 1];
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 1);
			goto restart;
		} else if (strncmp("-s", argv[i], 2) == 0) {
			do_fsync = 1;
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 1);
			goto restart;
		} else if (strncmp("-p", argv[i], 2) == 0) {
			psync = 1;
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 1);
			goto restart;
		} else if (strncmp("-w", argv[i], 2) == 0) {
			// wait_signal = 1;
			dash_d = i;
			argc = adjust_args(dash_d, argv, argc, 1);
			goto restart;
		}
	}

	return argc;
}

int main(int argc, char *argv[])
{
	int n_threads, i;
	std::vector<io_bench *> io_workers;
	unsigned long file_size_bytes;
	unsigned int io_size = 0;
	const char *device_id;

	device_id = getenv("FILE_ID");
	ops_cap = 0;
	do_fsync = 0;

	if (device_id)
		dev_id = atoi(device_id);
	else
		dev_id = 0;

	argc = process_opt_args(argc, argv);
	if (argc < 5) {
		io_bench::show_usage("tput_micro");
		exit(-1);
	}

	n_threads = std::stoi(argv[4]);

	file_size_bytes = io_bench::str_to_size(argv[2]);
	io_size = io_bench::str_to_size(argv[3]);

	/* One-file should be prepared and clean */
	if (io_bench::get_test_type(argv[1]) == PREPARE_DBOM ||
	    io_bench::get_test_type(argv[1]) == CLEAN_DBOM) {
		file_size_bytes = n_threads * file_size_bytes;
		n_threads = 1;
	}

	std::cout << "Total file size: " << file_size_bytes << "B" << endl
		  << "io size: " << io_size << "B" << endl
		  << "# of thread: " << n_threads << endl;

	if (!ops_cap)
		ops_cap = file_size_bytes / io_size;
	else
		ops_cap = min(file_size_bytes / io_size, ops_cap);

	printf("ops_cap is %lu\n", ops_cap);

	for (i = 0; i < n_threads; i++) {
		io_workers.push_back(
			new io_bench(i, file_size_bytes, io_size,
				     io_bench::get_test_type(argv[1])));
	}

	for (auto it : io_workers) {
		it->prepare();
		pthread_mutex_lock(&it->cv_mutex);
		it->per_thread_stats = 1;
	}

	for (auto it : io_workers)
		it->Start();

	for (auto it : io_workers)
		pthread_mutex_lock(&it->cv_mutex);

	for (auto it : io_workers)
		it->cleanup();

	for (auto it : io_workers)
		it->Join();

	time_t current_time;
	struct tm *time_info;
	char time_string[20];

	time(&current_time);
	time_info = localtime(&current_time);
	strftime(time_string, sizeof(time_string), "%Y-%m-%d %H:%M:%S",
		 time_info);
	printf("%s [oxbow_microbench] test done\n", time_string);

	fflush(stdout);
	fflush(stderr);

	return 0;
}
