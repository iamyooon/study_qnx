#include <stdio.h>
#include <stdlib.h>	// malloc
#include <unistd.h>	// sleep
#include <string.h>	// memset

int main()
{
	void *buf;
	while(1){
		sleep(1);
		buf = malloc(1024*1024);
		printf("after malloc(), %d\n", buf);
		memset(buf, '2', 1024*1024);
	}

	return 0;
}
