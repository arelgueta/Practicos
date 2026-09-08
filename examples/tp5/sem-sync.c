#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

union semun {
    int val;
    struct semid_ds *buf;
    unsigned short *array;
};

static unsigned long positive(const char *value, const char *option)
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
    fprintf(stderr, "Uso: %s [--workers N] [--hold-ms M]\n", name);
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

static int wait_for(pid_t pid, int *status)
{
    while (waitpid(pid, status, 0) == -1) {
        if (errno != EINTR)
            return -1;
    }
    return 0;
}

static void child(int semid, unsigned long hold_ms)
{
    struct sembuf acquire = {.sem_num = 0, .sem_op = -1, .sem_flg = 0};
    struct sembuf release = {.sem_num = 0, .sem_op = 1, .sem_flg = 0};

    if (semop(semid, &acquire, 1) == -1)
        _exit(1);
    dprintf(STDOUT_FILENO, "PID %ld adquirio el semaforo\n", (long)getpid());
    pause_ms(hold_ms);
    dprintf(STDOUT_FILENO, "PID %ld libera el semaforo\n", (long)getpid());
    if (semop(semid, &release, 1) == -1)
        _exit(1);
    _exit(0);
}

int main(int argc, char **argv)
{
    unsigned long workers = 3, hold_ms = 200;
    int semid, status, failed = 0;
    pid_t *pids;
    union semun initial = {.val = 1};

    setbuf(stdout, NULL);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--workers") == 0 && i + 1 < argc)
            workers = positive(argv[++i], "--workers");
        else if (strcmp(argv[i], "--hold-ms") == 0 && i + 1 < argc)
            hold_ms = positive(argv[++i], "--hold-ms");
        else {
            usage(argv[0]);
            return EXIT_FAILURE;
        }
    }
    if (workers > 64) {
        fprintf(stderr, "--workers no puede superar 64\n");
        return EXIT_FAILURE;
    }

    semid = semget(IPC_PRIVATE, 1, 0600);
    if (semid == -1) {
        perror("semget");
        return EXIT_FAILURE;
    }
    if (semctl(semid, 0, SETVAL, initial) == -1) {
        perror("semctl SETVAL");
        semctl(semid, 0, IPC_RMID);
        return EXIT_FAILURE;
    }
    pids = calloc(workers, sizeof(*pids));
    if (pids == NULL) {
        perror("calloc");
        semctl(semid, 0, IPC_RMID);
        return EXIT_FAILURE;
    }

    printf("semid=%d; consultalo con: ipcs -s\n", semid);
    for (unsigned long i = 0; i < workers; i++) {
        pids[i] = fork();
        if (pids[i] == -1) {
            perror("fork");
            failed = 1;
            break;
        }
        if (pids[i] == 0)
            child(semid, hold_ms);
    }
    if (failed) {
        for (unsigned long i = 0; i < workers; i++)
            if (pids[i] > 0)
                kill(pids[i], SIGTERM);
    }
    for (unsigned long i = 0; i < workers; i++)
        if (pids[i] > 0 && wait_for(pids[i], &status) == 0 && status != 0)
            failed = 1;

    if (semctl(semid, 0, IPC_RMID) == -1) {
        perror("semctl IPC_RMID");
        failed = 1;
    } else {
        printf("semid=%d eliminado\n", semid);
    }
    free(pids);
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}
