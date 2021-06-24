#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <process.h>

#include <sys/types.h>	// open()
#include <sys/stat.h>	// open()
#include <fcntl.h>	// open()

#include <unistd.h>	// sleep()

void *wewake_tid_thread(void *data)
{
	printf("wewake_tid_tread: %d\n", gettid());
	fflush(stdout);
}

void *wewake_create_pthread(void *data)
{
	pthread_t p_thread3;

	while (1)
	{
		pthread_create(&p_thread3, NULL, wewake_tid_thread, NULL);
		sleep(1);
	}
}

void *wewake_write_turn_sig(void *data)
{
	int fd;
	char turn_on[] = {"TurnSignal_State:i:3"};
	char turn_off[] = {"TurnSignal_State:i:0"};

	printf("wewake_write_turn_sig: %d\n", gettid());
	fflush(stdout);

	fd = open("/pps/VehicleInfo.pps", O_WRONLY);

	while(1)
	{
		printf("wewake turn on\n");
		fflush(stdout);
		write(fd, turn_on, sizeof(turn_on));
		usleep(400*1000);

		printf("wewake turn off\n");
		fflush(stdout);
		write(fd, turn_off, sizeof(turn_off));
		usleep(400*1000);
	}
}

int main(int argc, char** argv)
{
	pthread_t p_thread, p_thread2;
	int thread_id;
	int status, status2;

	pthread_create(&p_thread, NULL, wewake_create_pthread, NULL);
	pthread_create(&p_thread2, NULL, wewake_write_turn_sig, NULL);

	pthread_join(p_thread, (void **)&status);
	pthread_join(p_thread2, (void **)&status2);

	return 0;
}
