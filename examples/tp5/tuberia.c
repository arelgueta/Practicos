#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    int fd[2];
    pid_t productor;
    pid_t consumidor;
    if (pipe(fd) == -1) {
        perror("pipe");
        return EXIT_FAILURE;
    }

    productor = fork();
    if (productor == -1) {
        perror("fork");
        close(fd[0]);
        close(fd[1]);
        return EXIT_FAILURE;
    }
    if (productor == 0) {
        close(fd[0]);
        if (dup2(fd[1], STDOUT_FILENO) == -1) {
            perror("dup2");
            _exit(EXIT_FAILURE);
        }
        close(fd[1]);
        execlp("ls", "ls", (char *)NULL);
        perror("ls");
        _exit(EXIT_FAILURE);
    }

    consumidor = fork();
    if (consumidor == -1) {
        perror("fork");
        close(fd[0]);
        close(fd[1]);
        waitpid(productor, NULL, 0);
        return EXIT_FAILURE;
    }
    if (consumidor == 0) {
        close(fd[1]);
        if (dup2(fd[0], STDIN_FILENO) == -1) {
            perror("dup2");
            _exit(EXIT_FAILURE);
        }
        close(fd[0]);
        execlp("wc", "wc", (char *)NULL);
        perror("wc");
        _exit(EXIT_FAILURE);
    }

    close(fd[0]);
    close(fd[1]);
    waitpid(productor, NULL, 0);
    waitpid(consumidor, NULL, 0);
    return EXIT_SUCCESS;
}
