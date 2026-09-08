#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static void usage(const char *name)
{
    fprintf(stderr, "Uso: %s COMANDO [ARG...] -- COMANDO [ARG...]\n", name);
}

static int wait_for(pid_t pid, int *status)
{
    while (waitpid(pid, status, 0) == -1) {
        if (errno != EINTR)
            return -1;
    }
    return 0;
}

static int exit_status(int status)
{
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    if (WIFSIGNALED(status))
        return 128 + WTERMSIG(status);
    return EXIT_FAILURE;
}

int main(int argc, char **argv)
{
    int separator = 0;
    int pipefd[2];
    pid_t producer, consumer;
    int producer_status, consumer_status;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--") == 0) {
            separator = i;
            break;
        }
    }
    if (separator < 2 || separator + 1 >= argc) {
        usage(argv[0]);
        return EXIT_FAILURE;
    }
    argv[separator] = NULL;

    if (pipe(pipefd) == -1) {
        perror("pipe");
        return EXIT_FAILURE;
    }

    producer = fork();
    if (producer == -1) {
        perror("fork");
        close(pipefd[0]);
        close(pipefd[1]);
        return EXIT_FAILURE;
    }
    if (producer == 0) {
        close(pipefd[0]);
        if (dup2(pipefd[1], STDOUT_FILENO) == -1) {
            perror("dup2");
            _exit(127);
        }
        close(pipefd[1]);
        execvp(argv[1], &argv[1]);
        perror("execvp productor");
        _exit(127);
    }

    consumer = fork();
    if (consumer == -1) {
        perror("fork");
        kill(producer, SIGTERM);
        close(pipefd[0]);
        close(pipefd[1]);
        wait_for(producer, &producer_status);
        return EXIT_FAILURE;
    }
    if (consumer == 0) {
        close(pipefd[1]);
        if (dup2(pipefd[0], STDIN_FILENO) == -1) {
            perror("dup2");
            _exit(127);
        }
        close(pipefd[0]);
        execvp(argv[separator + 1], &argv[separator + 1]);
        perror("execvp consumidor");
        _exit(127);
    }

    close(pipefd[0]);
    close(pipefd[1]);
    if (wait_for(producer, &producer_status) == -1 ||
        wait_for(consumer, &consumer_status) == -1) {
        perror("waitpid");
        return EXIT_FAILURE;
    }
    return exit_status(consumer_status);
}
