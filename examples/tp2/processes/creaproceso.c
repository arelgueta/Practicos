#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

int main() {
    pid_t pid = fork();

    if (pid == -1) {
        perror("fork");
        return 1;
    }
    if (pid == 0)
        printf("Hijo: PID=%d PPID=%d\n", getpid(), getppid());
    else
        printf("Padre: PID=%d PPID=%d\n", getpid(), getppid());
    return 0;
}
