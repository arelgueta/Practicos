#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

static pthread_mutex_t resource_a = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t resource_b = PTHREAD_MUTEX_INITIALIZER;
#ifndef SAFE_ORDER
static pthread_barrier_t barrier;
#endif

static void *worker(void *argument) {
    int id = *(int *)argument;
    pthread_mutex_t *first = id == 0 ? &resource_a : &resource_b;
    pthread_mutex_t *second = id == 0 ? &resource_b : &resource_a;

#ifdef SAFE_ORDER
    first = &resource_a;
    second = &resource_b;
#endif
    pthread_mutex_lock(first);
    printf("hilo %d tomo su primer recurso\n", id);
#ifndef SAFE_ORDER
    pthread_barrier_wait(&barrier);
#endif
    pthread_mutex_lock(second);
    puts("seccion critica");
    pthread_mutex_unlock(second);
    pthread_mutex_unlock(first);
    return NULL;
}

int main(void) {
    pthread_t threads[2];
    int ids[] = {0, 1};

#ifndef SAFE_ORDER
    pthread_barrier_init(&barrier, NULL, 2);
#endif
    for (int i = 0; i < 2; i++) {
        pthread_create(&threads[i], NULL, worker, &ids[i]);
    }
    for (int i = 0; i < 2; i++) {
        pthread_join(threads[i], NULL);
    }
    puts("termino");
    return EXIT_SUCCESS;
}
