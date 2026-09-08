#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <sched.h>
#include <stdio.h>

#define THREADS 4
#define ITERATIONS 100000

static unsigned long counter;

#ifdef USE_MUTEX
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

static void *increment(void *argument) {
    (void)argument;
    for (unsigned long i = 0; i < ITERATIONS; i++) {
#ifdef USE_MUTEX
        pthread_mutex_lock(&mutex);
#endif
        unsigned long value = counter;
        sched_yield();
        counter = value + 1;
#ifdef USE_MUTEX
        pthread_mutex_unlock(&mutex);
#endif
    }
    return NULL;
}

int main(void) {
    pthread_t threads[THREADS];

    for (int i = 0; i < THREADS; i++) {
        pthread_create(&threads[i], NULL, increment, NULL);
    }
    for (int i = 0; i < THREADS; i++) {
        pthread_join(threads[i], NULL);
    }

    printf("esperado=%d observado=%lu\n", THREADS * ITERATIONS, counter);
#ifdef USE_MUTEX
    pthread_mutex_destroy(&mutex);
#endif
    return 0;
}
