#define _POSIX_C_SOURCE 200809L

#include <pthread.h>
#include <stdio.h>

#define CAPACITY 4
#define ITEMS 20

static int buffer[CAPACITY];
static int head;
static int tail;
static int count;
static int producer_done;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t not_empty = PTHREAD_COND_INITIALIZER;
static pthread_cond_t not_full = PTHREAD_COND_INITIALIZER;

static void *produce(void *argument) {
    (void)argument;
    for (int i = 0; i < ITEMS; i++) {
        pthread_mutex_lock(&mutex);
        while (count == CAPACITY) {
            pthread_cond_wait(&not_full, &mutex);
        }
        buffer[tail] = i;
        tail = (tail + 1) % CAPACITY;
        count++;
        pthread_cond_signal(&not_empty);
        pthread_mutex_unlock(&mutex);
    }

    pthread_mutex_lock(&mutex);
    producer_done = 1;
    pthread_cond_signal(&not_empty);
    pthread_mutex_unlock(&mutex);
    return NULL;
}

static void *consume(void *argument) {
    (void)argument;
    for (;;) {
        int value;
        pthread_mutex_lock(&mutex);
        while (count == 0 && !producer_done) {
            pthread_cond_wait(&not_empty, &mutex);
        }
        if (count == 0 && producer_done) {
            pthread_mutex_unlock(&mutex);
            return NULL;
        }
        value = buffer[head];
        head = (head + 1) % CAPACITY;
        count--;
        pthread_cond_signal(&not_full);
        pthread_mutex_unlock(&mutex);
        printf("consumido=%d\n", value);
    }
}

int main(void) {
    pthread_t producer, consumer;

    pthread_create(&producer, NULL, produce, NULL);
    pthread_create(&consumer, NULL, consume, NULL);
    pthread_join(producer, NULL);
    pthread_join(consumer, NULL);
    puts("buffer vacio");
    return 0;
}
