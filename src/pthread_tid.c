#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <process.h>

void *wewake_func_a(void *data)
{
	printf("wewake tid: %d\n", gettid());
}

int main(int argc, char** argv)
{
	pthread_t p_thread;
	int thread_id;
	int status;

	while (1)
	{
		pthread_create(&p_thread, NULL, wewake_func_a, NULL);
		//printf("wewake tid: %d\n", gettid());
		fflush(stdout);
		sleep(1);
	}
	return 0;
}
