#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct shared {
    unsigned long long counter;
    unsigned long long iterations;
    int use_mutex;
    int yield;
    pthread_mutex_t mutex;
};

static void usage(const char *name)
{
    fprintf(stderr,
            "Uso: %s --threads N --iterations M [--unsafe|--mutex] [--yield]\n",
            name);
}

static unsigned long long number(const char *value, const char *option)
{
    char *end;
    unsigned long long result;

    errno = 0;
    result = strtoull(value, &end, 10);
    if (errno || *value == '\0' || *end != '\0' || result == 0) {
        fprintf(stderr, "%s requiere un entero positivo\n", option);
        exit(EXIT_FAILURE);
    }
    return result;
}

static void check_pthread(int error, const char *operation)
{
    if (error != 0) {
        fprintf(stderr, "%s: %s\n", operation, strerror(error));
        exit(EXIT_FAILURE);
    }
}

static double elapsed(const struct timespec *start, const struct timespec *end)
{
    return (double)(end->tv_sec - start->tv_sec) +
           (double)(end->tv_nsec - start->tv_nsec) / 1000000000.0;
}

static void *worker(void *argument)
{
    struct shared *shared = argument;

    for (unsigned long long i = 0; i < shared->iterations; i++) {
        if (shared->use_mutex)
            check_pthread(pthread_mutex_lock(&shared->mutex), "pthread_mutex_lock");

        unsigned long long value = shared->counter;
        if (shared->yield)
            sched_yield();
        shared->counter = value + 1;

        if (shared->use_mutex)
            check_pthread(pthread_mutex_unlock(&shared->mutex), "pthread_mutex_unlock");
    }
    return NULL;
}

int main(int argc, char **argv)
{
    unsigned long long iterations = 1000000;
    unsigned long long thread_count = 2;
    struct shared shared = {.iterations = iterations};
    struct timespec start, end;
    pthread_t *threads;
    unsigned long long expected;
    unsigned long long created = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--threads") == 0 && i + 1 < argc)
            thread_count = number(argv[++i], "--threads");
        else if (strcmp(argv[i], "--iterations") == 0 && i + 1 < argc)
            iterations = number(argv[++i], "--iterations");
        else if (strcmp(argv[i], "--mutex") == 0)
            shared.use_mutex = 1;
        else if (strcmp(argv[i], "--unsafe") == 0)
            shared.use_mutex = 0;
        else if (strcmp(argv[i], "--yield") == 0)
            shared.yield = 1;
        else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (thread_count > UINT_MAX || iterations > ULLONG_MAX / thread_count) {
        fprintf(stderr, "cantidad de trabajo demasiado grande\n");
        return EXIT_FAILURE;
    }
    shared.iterations = iterations;
    if (shared.use_mutex)
        check_pthread(pthread_mutex_init(&shared.mutex, NULL), "pthread_mutex_init");

    threads = calloc((size_t)thread_count, sizeof(*threads));
    if (threads == NULL) {
        perror("calloc");
        return EXIT_FAILURE;
    }

    clock_gettime(CLOCK_MONOTONIC, &start);
    for (unsigned long long i = 0; i < thread_count; i++) {
        int error = pthread_create(&threads[i], NULL, worker, &shared);
        if (error != 0) {
            fprintf(stderr, "pthread_create: %s\n", strerror(error));
            break;
        }
        created++;
    }
    for (unsigned long long i = 0; i < created; i++)
        check_pthread(pthread_join(threads[i], NULL), "pthread_join");
    clock_gettime(CLOCK_MONOTONIC, &end);

    expected = thread_count * iterations;
    printf("threads=%llu iterations=%llu mode=%s expected=%llu observed=%llu elapsed=%.3f s\n",
           thread_count, iterations, shared.use_mutex ? "mutex" : "unsafe",
           expected, shared.counter, elapsed(&start, &end));

    free(threads);
    if (shared.use_mutex)
        check_pthread(pthread_mutex_destroy(&shared.mutex), "pthread_mutex_destroy");
    return created == thread_count ? EXIT_SUCCESS : EXIT_FAILURE;
}
