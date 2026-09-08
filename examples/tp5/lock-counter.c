#define _XOPEN_SOURCE 700

#include <errno.h>
#include <limits.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static unsigned long number(const char *value, const char *option)
{
    char *end;
    unsigned long result;

    errno = 0;
    result = strtoul(value, &end, 10);
    if (errno || *value == '\0' || *end != '\0' || result == 0) {
        fprintf(stderr, "%s requiere un entero positivo\n", option);
        exit(EXIT_FAILURE);
    }
    return result;
}

static void usage(const char *name)
{
    fprintf(stderr,
            "Uso: %s --file RUTA --workers N --rounds R [--unsafe|--lock]\n",
            name);
}

static void pause_ms(unsigned long milliseconds)
{
    struct timespec remaining = {
        .tv_sec = milliseconds / 1000,
        .tv_nsec = (long)(milliseconds % 1000) * 1000000L,
    };
    while (nanosleep(&remaining, &remaining) == -1 && errno == EINTR)
        ;
}

static int update_file(const char *path, unsigned long rounds, int use_lock)
{
    int fd = open(path, O_RDWR);
    if (fd == -1)
        return -1;

    for (unsigned long i = 0; i < rounds; i++) {
        long long value;
        if (use_lock && lockf(fd, F_LOCK, sizeof(value)) == -1) {
            close(fd);
            return -1;
        }
        if (pread(fd, &value, sizeof(value), 0) != (ssize_t)sizeof(value)) {
            if (use_lock)
                lockf(fd, F_ULOCK, sizeof(value));
            close(fd);
            return -1;
        }
        pause_ms(1);
        value++;
        if (pwrite(fd, &value, sizeof(value), 0) != (ssize_t)sizeof(value)) {
            if (use_lock)
                lockf(fd, F_ULOCK, sizeof(value));
            close(fd);
            return -1;
        }
        if (use_lock && lockf(fd, F_ULOCK, sizeof(value)) == -1) {
            close(fd);
            return -1;
        }
    }
    close(fd);
    return 0;
}

int main(int argc, char **argv)
{
    const char *path = NULL;
    unsigned long workers = 3, rounds = 100;
    int use_lock = 0, fd, status, failed = 0;
    pid_t *pids;
    long long result = 0, expected;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--file") == 0 && i + 1 < argc)
            path = argv[++i];
        else if (strcmp(argv[i], "--workers") == 0 && i + 1 < argc)
            workers = number(argv[++i], "--workers");
        else if (strcmp(argv[i], "--rounds") == 0 && i + 1 < argc)
            rounds = number(argv[++i], "--rounds");
        else if (strcmp(argv[i], "--lock") == 0)
            use_lock = 1;
        else if (strcmp(argv[i], "--unsafe") == 0)
            use_lock = 0;
        else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }
    if (path == NULL || workers > ULONG_MAX / rounds) {
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    fd = open(path, O_CREAT | O_TRUNC | O_RDWR, 0600);
    if (fd == -1) {
        perror("open");
        return EXIT_FAILURE;
    }
    long long zero = 0;
    if (pwrite(fd, &zero, sizeof(zero), 0) != (ssize_t)sizeof(zero)) {
        perror("pwrite");
        close(fd);
        return EXIT_FAILURE;
    }
    close(fd);

    pids = calloc(workers, sizeof(*pids));
    if (pids == NULL) {
        perror("calloc");
        return EXIT_FAILURE;
    }
    for (unsigned long i = 0; i < workers; i++) {
        pids[i] = fork();
        if (pids[i] == -1) {
            perror("fork");
            failed = 1;
            break;
        }
        if (pids[i] == 0)
            _exit(update_file(path, rounds, use_lock) == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
    }
    if (failed) {
        for (unsigned long i = 0; i < workers; i++)
            if (pids[i] > 0)
                kill(pids[i], SIGTERM);
    }
    for (unsigned long i = 0; i < workers; i++)
        if (pids[i] > 0 && waitpid(pids[i], &status, 0) == -1)
            failed = 1;
        else if (pids[i] > 0 && (!WIFEXITED(status) || WEXITSTATUS(status) != 0))
            failed = 1;

    fd = open(path, O_RDONLY);
    if (fd != -1) {
        if (pread(fd, &result, sizeof(result), 0) != (ssize_t)sizeof(result))
            failed = 1;
        close(fd);
    } else {
        failed = 1;
    }
    expected = (long long)(workers * rounds);
    printf("workers=%lu rounds=%lu mode=%s expected=%lld observed=%lld file=%s\n",
           workers, rounds, use_lock ? "lockf" : "unsafe", expected, result, path);
    free(pids);
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}
