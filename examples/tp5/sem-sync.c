#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/wait.h>
#include <unistd.h>

#define WORKERS 3

union semun {
    int val;
};

static void work(int semid) {
    struct sembuf acquire = {0, -1, 0};
    struct sembuf release = {0, 1, 0};

    semop(semid, &acquire, 1);
    dprintf(STDOUT_FILENO, "PID %ld entro\n", (long)getpid());
    sleep(1);
    dprintf(STDOUT_FILENO, "PID %ld sale\n", (long)getpid());
    semop(semid, &release, 1);
    _exit(EXIT_SUCCESS);
}

int main(void) {
    union semun initial = {1};
    int semid = semget(IPC_PRIVATE, 1, 0600);
    pid_t children[WORKERS];

    if (semid == -1) {
        perror("semget");
        return EXIT_FAILURE;
    }
    if (semctl(semid, 0, SETVAL, initial) == -1) {
        perror("semctl");
        return EXIT_FAILURE;
    }

    setbuf(stdout, NULL);
    printf("semid=%d; consultalo con: ipcs -s\n", semid);
    for (int i = 0; i < WORKERS; i++) {
        children[i] = fork();
        if (children[i] == 0) {
            work(semid);
        }
    }
    for (int i = 0; i < WORKERS; i++) {
        waitpid(children[i], NULL, 0);
    }

    semctl(semid, 0, IPC_RMID);
    printf("semid=%d eliminado\n", semid);
    return 0;
}
