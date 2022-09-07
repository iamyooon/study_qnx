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

void parse_opt(int argc, char **argv)
{
        int c;
        opterr = 0;
        while ((c = getopt(argc, argv, "m:o:t:")) != -1){
                switch (c)
                {
                        case 'm':
                                //printf("option=>%c arg=>%s\n", c, optarg);
				capture_mode = strtoul(optarg, NULL, 0);
                                break;
                        case 't':
                                //printf("option=>%c arg=>%s\n", c, optarg);
				capture_time = strtoul(optarg, NULL, 0);
                                break;
                        case 'o':
                                //printf("option=>%c arg=>%s\n", c, optarg);
				log_path = strdup(optarg);
                                break;
                        default:
                                //printf("what! [%s]\n",optarg);
                                break;
                }
        }
}

void iterate_process(int pid, char* cmdline, char* exefile)
{
	char paths[32]={0};
	int fd;
	int i=0;
	int ret;

	sprintf(paths, "/proc/%d/cmdline", pid);
	fd = open(paths, O_RDONLY);
	if (0 > fd) {
		//printf("%s file open failed.\n", paths);
		//perror(NULL);
		//exit (EXIT_FAILURE);
		for (i=0; cmdline[i]!=0; i++) {
			if(cmdline[i]=='\n') {
				cmdline[i]=0;
				break;
			}
		}
	}
	else {
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
	}
	close(fd);

	sprintf(paths, "/proc/%d/exefile", pid);
	fd = open(paths, O_RDONLY);
	if (0 > fd) {
		//printf("%s file open failed.\n", paths);
		//perror(NULL);
		//exit (EXIT_FAILURE);
		for (i=0; exefile[i]!=0; i++) {
			if(exefile[i]=='\n') {
				exefile[i]=0;
				break;
			}
		}
	}
	else {
		ret = read(fd, exefile, CMD_BUF_SIZE);
		if(ret == 0){
			memset(exefile,0,sizeof(exefile));
		}
		//printf("read length is %d\n",ret);

		for (i=0; exefile[i]!=0; i++) {
			if(exefile[i]=='\n') {
				exefile[i]=0;
				break;
			}
		}
	}
	close(fd);
}

unsigned long long get_start_time_from_proc (int fd, int pid)
{
	procfs_info info;
	int sts = EOK;
	unsigned long long start_time=0;

	sts = devctl(fd, DCMD_PROC_INFO, &info, sizeof(info), NULL);

	if (sts != EOK){
	  fprintf(stderr, "%s: DCMD_PROC_INFO pid %d error %d (%s)\n",
	          "get_start_time_from_proc", pid, sts, strerror (sts));
	  exit(EXIT_FAILURE);
	}
	start_time = info.start_time;
	return start_time;
}

void capture_all_proc_start_time (int log_fd, int time_delta)
{
	int fd;
	int pid = 0;
	struct dirent *dirent;
	DIR *dir;
	char path[32]={0,};
	unsigned long long time_from_epoch=0;
	clockid_t clk_id;
	struct timespec tp;
	double time_from_boot=0;
	int mtime_from_boot=0;
	int time=0;
	char proc_data[4096]={0,};
	int i, data_size;
	char cmdline[32]={0,};
	char exefile[64]={0,};

	clk_id = CLOCK_MONOTONIC;

	// 1) find all processes
	if (!(dir = opendir ("/proc"))) {
		printf("wewake couldn't open /proc\n");
		perror (NULL);
		exit (EXIT_FAILURE);
	}

	while (dirent = readdir(dir)) {
		// 2) we are only interested in process IDs
		if (isdigit (*dirent -> d_name)) {
			pid = atoi (dirent -> d_name);
			sprintf(path, "/proc/%d/as", pid);
			fd = open(path, O_RDONLY);
			if (0 > fd) {
				//printf("%s file open failed.\n", path);
				//perror(NULL);
				//exit (EXIT_FAILURE);
			}
			else {
				// read cmdline, exefile
				iterate_process(pid, cmdline, exefile);

				time_from_epoch = get_start_time_from_proc(fd, pid);
				time = time_from_epoch/10000000 - time_delta;

				if (capture_mode==1 && time > capture_time*100)
					continue;

				sprintf(proc_data, "%d\n", time);
				for (i=0; proc_data[i]!=0; i++) {
					if(proc_data[i]=='\n') {
						data_size=i+1;
						break;
					}
				}
				write(log_fd, proc_data, data_size);

				sprintf(proc_data, "%d,%d,%s[%s],%d,%d,%d\n", pid, 0, cmdline, exefile, 0, 0, 0);

				for (i=0; proc_data[i]!=0; i++) {
					if(proc_data[i]=='\n') {
						data_size=i+1;
						break;
					}
				}
				write(log_fd, proc_data, data_size);

				sprintf(proc_data, "\n");
				for (i=0; proc_data[i]!=0; i++) {
					if(proc_data[i]=='\n') {
						data_size=i+1;
						break;
					}
				}
				write(log_fd, proc_data, data_size);

				if (capture_mode==1) {
					sprintf(proc_data, "%d\n", capture_time*100);
					for (i=0; proc_data[i]!=0; i++) {
						if(proc_data[i]=='\n') {
							data_size=i+1;
							break;
						}
					}
					write(log_fd, proc_data, data_size);

					sprintf(proc_data, "%d,%d,%s[%s],%d,%d,%d\n", pid, 0, cmdline, exefile, 0, 0, 0);

					for (i=0; proc_data[i]!=0; i++) {
						if(proc_data[i]=='\n') {
							data_size=i+1;
							break;
						}
					}
					write(log_fd, proc_data, data_size);

					sprintf(proc_data, "\n");
					for (i=0; proc_data[i]!=0; i++) {
						if(proc_data[i]=='\n') {
							data_size=i+1;
							break;
						}
					}
				write(log_fd, proc_data, data_size);
				}
			}
			close(fd);
		}
	}
	closedir(dir);
}

void capture_proc_stats(int log_fd)
{
	int pid = 0;
	struct dirent *dirent;
	DIR *dir;
	clockid_t clk_id;
	struct timespec tp;
	double time_from_boot=0;
	int mtime_from_boot=0;
	char proc_data[4096]={0,};
	int i, data_size;
	char cmdline[32]={0,};
	char exefile[64]={0,};

	clk_id = CLOCK_MONOTONIC;

	while(1)
	{
		// 1) find all processes
		if (!(dir = opendir ("/proc"))) {
			printf("wewake couldn't open /proc\n");
			perror (NULL);
			exit (EXIT_FAILURE);
		}

		clock_gettime(clk_id, &tp);
		time_from_boot = tp.tv_sec + (double)tp.tv_nsec/(double)1000000000L;
		//printf("capture time(s): %lf\n", time_from_boot);
		mtime_from_boot = time_from_boot*100;
		//printf("capture time(10ms): %d\n", mtime_from_boot);
		sprintf(proc_data, "%d\n", mtime_from_boot);

		for (i=0; proc_data[i]!=0; i++) {
			if(proc_data[i]=='\n') {
				data_size=i+1;
				break;
			}
		}
		write(log_fd, proc_data, data_size);

		while(dirent = readdir(dir)) {
			// 2) we are only interested in process IDs
			if (isdigit(*dirent -> d_name)) {
				pid = atoi (dirent -> d_name);
				iterate_process(pid, cmdline, exefile);
				sprintf(proc_data, "%d,%d,%s[%s],%d,%d,%d\n", pid, 0, cmdline, exefile, 0, 0, 0);
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
	char logpath[32]={0,};
	int log_fd, fd;
	int pid = 0;
	DIR *dir;
	char path[32]={0,};
	unsigned long long time_from_epoch=0;
	clockid_t clk_id;
	struct timespec tp;
	double time_from_boot=0;
	int mtime_from_epoch=0;
	int mtime_from_boot=0;
	int time_delta;
	int i=0;

	mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
	clk_id = CLOCK_MONOTONIC;

	// 0. option parsing
	parse_opt(argc, argv);

	for (i=0; i<32; i++) {
		logpath[i]=log_path[i];
	}
	//printf("logpath %s\n", logpath);
	//printf("capture mode %d\n", capture_mode);
	//printf("capture time %d\n", capture_time);
	log_fd = open(logpath, O_CREAT | O_TRUNC | O_WRONLY, mode);
	if (0 > log_fd) {
		printf("file open failed.\n");
		perror(NULL);
		exit (EXIT_FAILURE);
	}

	//printf("bootchart pid=%d\n", pid);
	//printf("time_from_epoch=%d, time_from_boot=%d, time_delta=%d\n", mtime_from_epoch, mtime_from_boot, time_delta);
	// 1) find start time from epoch
	pid = getpid();
	sprintf(path, "/proc/%d/as", pid);
	fd = open(path, O_RDONLY);
	if (0 > fd) {
		printf("%s file open failed.\n", path);
		perror(NULL);
		exit (EXIT_FAILURE);
	}
	time_from_epoch = get_start_time_from_proc(fd, pid);
	close(fd);

	//printf("bootchart pid=%d, start_time=%llx(epoch)\n", pid, time_from_epoch);

	// 2) find start time from boot
	clock_gettime(clk_id, &tp);
	time_from_boot = tp.tv_sec + (double)tp.tv_nsec/(double)1000000000L;
	//printf("bootchart start_time=%lf(boottime(sec))\n", time_from_boot);

	// 3) adjust time resolution
	// nsec to 10ms
	mtime_from_epoch = time_from_epoch/10000000;
	// sec to 10ms
	mtime_from_boot = time_from_boot*100;

	// 4) get delta
	time_delta = mtime_from_epoch - mtime_from_boot;

	if (capture_mode==1) {
		capture_all_proc_start_time(log_fd, time_delta);
	}
	else if (capture_mode==2) {
		capture_proc_stats(log_fd);
	}
	else if (capture_mode==3) {
		capture_all_proc_start_time(log_fd, time_delta);
		capture_proc_stats(log_fd);
	}

	return 0;
}
