#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int global_data = 4;
int global_data_2;
static const char message[] = "hello, world";

static int marker() {
    return 7;
}

int main() {
    int local_data = 3;
    int *heap_data = malloc(sizeof *heap_data);

    if (heap_data == NULL) {
        perror("malloc");
        return 1;
    }

    *heap_data = 42;
    printf("PID: %d\n", getpid());
    printf("mensaje:     %s @ %p\n", message, (void *)message);
    printf("global_data: %d @ %p\n", global_data, (void *)&global_data);
    printf("global_data_2: %d @ %p\n", global_data_2, (void *)&global_data_2);
    printf("local_data:  %d @ %p\n", local_data, (void *)&local_data);
    printf("funcion: 0x%" PRIxPTR "\n", (uintptr_t)marker);
    printf("heap_data: %p\n", (void *)heap_data);
    fflush(stdout);

    sleep(30);
    free(heap_data);
    return 0;
}
