#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/fs.h> // Common filesystem definitions
#include <errno.h>

#define EXT4_IOC_CHECKPOINT _IOW('f', 43, __u32)
#define EXT4_IOC_CHECKPOINT_FLAG_DRY_RUN 0x4

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <device>\n", argv[0]);
		return EXIT_FAILURE;
	}

	const char *device = argv[1]; // Device path from command line argument
	int flag = EXT4_IOC_CHECKPOINT_FLAG_DRY_RUN;

	printf("Root path %s\n", device);

	// Open the device file
	int fd = open(device,
		      O_RDONLY); // Use O_RDONLY for safety if not modifying
	if (fd == -1) {
		perror("Failed to open device");
		return EXIT_FAILURE;
	}

	// Execute the EXT4_IOC_CHECKPOINT ioctl
	int ret = ioctl(fd, EXT4_IOC_CHECKPOINT, &flag);
	if (ret == -1) {
		perror("ioctl EXT4_IOC_CHECKPOINT failed");
		close(fd);
		return EXIT_FAILURE;
	}

	printf("Checkpoint successfully executed on %s\n", device);

	// Close the device
	close(fd);
	return EXIT_SUCCESS;
}
