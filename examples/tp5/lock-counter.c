#define _XOPEN_SOURCE 700

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define WORKERS 3
#define ROUNDS 100

static void pause_briefly(void) {
    struct timespec delay = {0, 1000000};
    nanosleep(&delay, NULL);
}

static void update(const char *path) {
    int fd = open(path, O_RDWR);
    long long value;

    for (int i = 0; i < ROUNDS; i++) {
#ifdef USE_LOCK
        lockf(fd, F_LOCK, sizeof(value));
#endif
        pread(fd, &value, sizeof(value), 0);
        pause_briefly();
        value++;
        pwrite(fd, &value, sizeof(value), 0);
#ifdef USE_LOCK
        lockf(fd, F_ULOCK, sizeof(value));
#endif
    }
    close(fd);
    _exit(EXIT_SUCCESS);
}

int main(void) {
    const char *path = "counter";
    long long zero = 0;
    long long result;
    int fd;

    fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600);
    pwrite(fd, &zero, sizeof(zero), 0);
    close(fd);

    for (int i = 0; i < WORKERS; i++) {
        if (fork() == 0) {
            update(path);
        }
    }
    for (int i = 0; i < WORKERS; i++) {
        wait(NULL);
    }

    fd = open(path, O_RDONLY);
    pread(fd, &result, sizeof(result), 0);
    close(fd);
    printf("esperado=%d observado=%lld\n", WORKERS * ROUNDS, result);
    unlink(path);
    return 0;
}
