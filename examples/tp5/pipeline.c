#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void) {
    int pipefd[2];
    pid_t producer, consumer;

    if (pipe(pipefd) == -1) {
        perror("pipe");
        return EXIT_FAILURE;
    }

    producer = fork();
    if (producer == -1) {
        perror("fork");
        return EXIT_FAILURE;
    }
    if (producer == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        execlp("printf", "printf", "uno\ndos\ntres\n", NULL);
        perror("exec printf");
        _exit(127);
    }

    consumer = fork();
    if (consumer == -1) {
        perror("fork");
        return EXIT_FAILURE;
    }
    if (consumer == 0) {
        close(pipefd[1]);
        dup2(pipefd[0], STDIN_FILENO);
        close(pipefd[0]);
        execlp("wc", "wc", "-l", NULL);
        perror("exec wc");
        _exit(127);
    }

    close(pipefd[0]);
    close(pipefd[1]);
    waitpid(producer, NULL, 0);
    waitpid(consumer, NULL, 0);
    return 0;
}
