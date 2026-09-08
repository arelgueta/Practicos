#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct shared {
    pthread_mutex_t first;
    pthread_mutex_t second;
    pthread_barrier_t barrier;
    int ordered;
};

struct worker_arg {
    struct shared *shared;
    int id;
};

static void usage(const char *name)
{
    fprintf(stderr, "Uso: %s [--ordered|--deadlock]\n", name);
}

static void lock(pthread_mutex_t *mutex, const char *name)
{
    int error = pthread_mutex_lock(mutex);
    if (error != 0) {
        fprintf(stderr, "pthread_mutex_lock %s: %s\n", name, strerror(error));
        exit(EXIT_FAILURE);
    }
}

static void unlock(pthread_mutex_t *mutex, const char *name)
{
    int error = pthread_mutex_unlock(mutex);
    if (error != 0) {
        fprintf(stderr, "pthread_mutex_unlock %s: %s\n", name, strerror(error));
        exit(EXIT_FAILURE);
    }
}

static void *worker(void *argument)
{
    struct worker_arg *worker = argument;
    struct shared *shared = worker->shared;
    pthread_mutex_t *first = &shared->first;
    pthread_mutex_t *second = &shared->second;
    const char *first_name = "A";
    const char *second_name = "B";

    if (!shared->ordered && worker->id == 1) {
        first = &shared->second;
        second = &shared->first;
        first_name = "B";
        second_name = "A";
    }
    lock(first, first_name);
    printf("hilo %d tomo %s\n", worker->id, first_name);
    fflush(stdout);
    if (!shared->ordered)
        pthread_barrier_wait(&shared->barrier);
    printf("hilo %d espera %s\n", worker->id, second_name);
    fflush(stdout);
    lock(second, second_name);
    unlock(second, second_name);
    unlock(first, first_name);
    printf("hilo %d termino\n", worker->id);
    fflush(stdout);
    return NULL;
}

int main(int argc, char **argv)
{
    struct shared shared = {.ordered = 1};
    struct worker_arg args[2];
    pthread_t threads[2];

    if (argc == 2 && strcmp(argv[1], "--deadlock") == 0)
        shared.ordered = 0;
    else if (argc != 1 && !(argc == 2 && strcmp(argv[1], "--ordered") == 0)) {
        usage(argv[0]);
        return EXIT_FAILURE;
    }
    setbuf(stdout, NULL);
    pthread_mutex_init(&shared.first, NULL);
    pthread_mutex_init(&shared.second, NULL);
    if (!shared.ordered)
        pthread_barrier_init(&shared.barrier, NULL, 2);

    for (int i = 0; i < 2; i++) {
        args[i] = (struct worker_arg){&shared, i};
        if (pthread_create(&threads[i], NULL, worker, &args[i]) != 0)
            return EXIT_FAILURE;
    }
    for (int i = 0; i < 2; i++)
        pthread_join(threads[i], NULL);

    if (!shared.ordered)
        pthread_barrier_destroy(&shared.barrier);
    pthread_mutex_destroy(&shared.first);
    pthread_mutex_destroy(&shared.second);
    puts("termino sin interbloqueo");
    return EXIT_SUCCESS;
}
