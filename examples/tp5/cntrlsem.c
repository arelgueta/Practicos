#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/sem.h>

int main(int argc, char *argv[])
{
    char *final;
    long valor;

    if (argc != 2) {
        fprintf(stderr, "Uso: %s SEMID\n", argv[0]);
        return EXIT_FAILURE;
    }

    errno = 0;
    valor = strtol(argv[1], &final, 10);
    if (errno != 0 || *final != '\0' || valor < 0 || valor > INT_MAX) {
        fprintf(stderr, "SEMID invalido: %s\n", argv[1]);
        return EXIT_FAILURE;
    }
    if (semctl((int)valor, 0, IPC_RMID) == -1) {
        perror("semctl IPC_RMID");
        return EXIT_FAILURE;
    }

    puts("Semaforo eliminado.");
    return EXIT_SUCCESS;
}
