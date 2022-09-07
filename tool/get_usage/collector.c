#include <stdio.h>
#include <stdlib.h>	// EXIT_FAILURE
#include <sys/procfs.h> // devctl()
#include <errno.h>	// EOK
#include <string.h>	// strerror()
#include <ctype.h>	// isdigit
#include <dirent.h>	// DIR
#include <fcntl.h>	// open()
#include <sys/stat.h>	// open()
#include <sys/types.h>	// open()
#include <stdint.h>	// uinit64_t
#include <time.h>
#include <unistd.h>     // gettopt()

#define COMM_BUF_SIZE 2048
#define CMD_BUF_SIZE 2048
#define INTERVAL 100000

int capture_mode;
char *log_path;
int capture_time;

void iterate_process(int pid, char* cmdline)
{
	char paths[32]={0};
	int fd;
	int i=0;
	int ret;

	sprintf(paths, "/proc/%d/cmdline", pid);
	fd = open(paths, O_RDONLY);

	ret = read(fd, cmdline, 32);
	if(ret == 0){
		memset(cmdline,0,sizeof(cmdline));
	}

	for (i=0; cmdline[i]!=0; i++) {
		if(cmdline[i]=='\n') {
			cmdline[i]=0;
			break;
		}
	}
	close(fd);
}

void capture_proc(int log_fd)
{
	int pid = 0;
	struct dirent *dirent;
	DIR *dir;
	char proc_data[4096]={0,};
	int i, data_size;
	char cmdline[32]={0,};

	while(1)
	{
		// 1) find all processes
		if (!(dir = opendir ("/proc"))) {
			printf("wewake couldn't open /proc\n");
			perror (NULL);
			exit (EXIT_FAILURE);
		}

		while(dirent = readdir(dir)) {
			// 2) we are only interested in process IDs
			if (isdigit(*dirent -> d_name)) {
				pid = atoi (dirent -> d_name);
				iterate_process(pid, cmdline);
				sprintf(proc_data, "%d,%d\n", pid, cmdline);
				for (i=0; proc_data[i]!=0; i++) {
					if(proc_data[i]=='\n') {
						data_size=i+1;
						break;
					}
				}
				write(log_fd, proc_data, data_size);
			}
		}
		sprintf(proc_data, "\n");
		for (i=0; proc_data[i]!=0; i++) {
			if(proc_data[i]=='\n') {
				data_size=i+1;
				break;
			}
		}
		write(log_fd, proc_data, data_size);
		closedir(dir);
		usleep(INTERVAL);
	}
}

int main(int argc, char** argv)
{
	capture_proc(log_fd);

	return 0;
}
