#include <stdio.h>
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/sem.h>

int main(void)
{
    struct sembuf incrementar = {
        .sem_num = 0,
        .sem_op = 1,
        .sem_flg = 0,
    };
    int semid = semget(IPC_PRIVATE, 1, 0666);

    if (semid == -1) {
        perror("semget");
        return EXIT_FAILURE;
    }
    if (semop(semid, &incrementar, 1) == -1) {
        perror("semop");
        semctl(semid, 0, IPC_RMID);
        return EXIT_FAILURE;
    }

    printf("Conjunto creado: %d\n", semid);
    printf("Valor inicial: 1 (recurso disponible).\n");
    printf("Eliminar con: ./cntrlsem %d\n", semid);
    return EXIT_SUCCESS;
}
