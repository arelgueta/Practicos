#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct item {
    unsigned long producer;
    unsigned long sequence;
};

struct queue {
    struct item *items;
    unsigned long capacity;
    unsigned long head;
    unsigned long tail;
    unsigned long count;
    unsigned long producers_left;
    unsigned long consumed;
    unsigned long long sequence_sum;
    int closed;
    pthread_mutex_t mutex;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
};

struct producer_arg {
    struct queue *queue;
    unsigned long id;
    unsigned long items;
};

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
    fprintf(stderr, "Uso: %s --producers P --consumers C --items N --capacity K\n", name);
}

static void check_pthread(int error, const char *operation)
{
    if (error != 0) {
        fprintf(stderr, "%s: %s\n", operation, strerror(error));
        exit(EXIT_FAILURE);
    }
}

static void put(struct queue *queue, struct item item)
{
    check_pthread(pthread_mutex_lock(&queue->mutex), "pthread_mutex_lock");
    while (queue->count == queue->capacity)
        check_pthread(pthread_cond_wait(&queue->not_full, &queue->mutex),
                      "pthread_cond_wait");

    queue->items[queue->tail] = item;
    queue->tail = (queue->tail + 1) % queue->capacity;
    queue->count++;
    check_pthread(pthread_cond_signal(&queue->not_empty), "pthread_cond_signal");
    check_pthread(pthread_mutex_unlock(&queue->mutex), "pthread_mutex_unlock");
}

static int get(struct queue *queue, struct item *item)
{
    check_pthread(pthread_mutex_lock(&queue->mutex), "pthread_mutex_lock");
    while (queue->count == 0 && !queue->closed)
        check_pthread(pthread_cond_wait(&queue->not_empty, &queue->mutex),
                      "pthread_cond_wait");

    if (queue->count == 0 && queue->closed) {
        check_pthread(pthread_mutex_unlock(&queue->mutex), "pthread_mutex_unlock");
        return 0;
    }

    *item = queue->items[queue->head];
    queue->head = (queue->head + 1) % queue->capacity;
    queue->count--;
    queue->consumed++;
    queue->sequence_sum += item->sequence;
    check_pthread(pthread_cond_signal(&queue->not_full), "pthread_cond_signal");
    check_pthread(pthread_mutex_unlock(&queue->mutex), "pthread_mutex_unlock");
    return 1;
}

static void *produce(void *argument)
{
    struct producer_arg *producer = argument;

    for (unsigned long i = 0; i < producer->items; i++)
        put(producer->queue, (struct item){producer->id, i});

    check_pthread(pthread_mutex_lock(&producer->queue->mutex), "pthread_mutex_lock");
    producer->queue->producers_left--;
    if (producer->queue->producers_left == 0) {
        producer->queue->closed = 1;
        check_pthread(pthread_cond_broadcast(&producer->queue->not_empty),
                      "pthread_cond_broadcast");
    }
    check_pthread(pthread_mutex_unlock(&producer->queue->mutex), "pthread_mutex_unlock");
    return NULL;
}

static void *consume(void *argument)
{
    struct queue *queue = argument;
    struct item item;

    while (get(queue, &item))
        ;
    return NULL;
}

int main(int argc, char **argv)
{
    unsigned long producers = 2, consumers = 2, items_per_producer = 1000;
    unsigned long capacity = 8;
    struct queue queue;
    struct producer_arg *producer_args;
    pthread_t *producer_threads, *consumer_threads;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--producers") == 0 && i + 1 < argc)
            producers = number(argv[++i], "--producers");
        else if (strcmp(argv[i], "--consumers") == 0 && i + 1 < argc)
            consumers = number(argv[++i], "--consumers");
        else if (strcmp(argv[i], "--items") == 0 && i + 1 < argc)
            items_per_producer = number(argv[++i], "--items");
        else if (strcmp(argv[i], "--capacity") == 0 && i + 1 < argc)
            capacity = number(argv[++i], "--capacity");
        else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }

    if (producers > ULONG_MAX / items_per_producer) {
        fprintf(stderr, "cantidad de elementos demasiado grande\n");
        return EXIT_FAILURE;
    }
    queue = (struct queue){
        .capacity = capacity,
        .producers_left = producers,
        .items = calloc(capacity, sizeof(*queue.items)),
    };
    producer_args = calloc(producers, sizeof(*producer_args));
    producer_threads = calloc(producers, sizeof(*producer_threads));
    consumer_threads = calloc(consumers, sizeof(*consumer_threads));
    if (!queue.items || !producer_args || !producer_threads || !consumer_threads) {
        perror("calloc");
        return EXIT_FAILURE;
    }

    check_pthread(pthread_mutex_init(&queue.mutex, NULL), "pthread_mutex_init");
    check_pthread(pthread_cond_init(&queue.not_empty, NULL), "pthread_cond_init");
    check_pthread(pthread_cond_init(&queue.not_full, NULL), "pthread_cond_init");

    for (unsigned long i = 0; i < consumers; i++)
        check_pthread(pthread_create(&consumer_threads[i], NULL, consume, &queue),
                      "pthread_create");
    for (unsigned long i = 0; i < producers; i++) {
        producer_args[i] = (struct producer_arg){&queue, i, items_per_producer};
        check_pthread(pthread_create(&producer_threads[i], NULL, produce,
                                     &producer_args[i]), "pthread_create");
    }
    for (unsigned long i = 0; i < producers; i++)
        check_pthread(pthread_join(producer_threads[i], NULL), "pthread_join");
    for (unsigned long i = 0; i < consumers; i++)
        check_pthread(pthread_join(consumer_threads[i], NULL), "pthread_join");

    unsigned long expected_items = producers * items_per_producer;
    unsigned long long expected_sum = (unsigned long long)producers *
                                      items_per_producer * (items_per_producer - 1) / 2;
    printf("producers=%lu consumers=%lu capacity=%lu expected=%lu consumed=%lu "
           "expected_sequence_sum=%llu sequence_sum=%llu remaining=%lu\n",
           producers, consumers, capacity, expected_items, queue.consumed,
           expected_sum, queue.sequence_sum, queue.count);

    check_pthread(pthread_cond_destroy(&queue.not_empty), "pthread_cond_destroy");
    check_pthread(pthread_cond_destroy(&queue.not_full), "pthread_cond_destroy");
    check_pthread(pthread_mutex_destroy(&queue.mutex), "pthread_mutex_destroy");
    free(queue.items);
    free(producer_args);
    free(producer_threads);
    free(consumer_threads);
    return queue.consumed == expected_items && queue.sequence_sum == expected_sum
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
}
