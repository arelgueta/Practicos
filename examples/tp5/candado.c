#define _XOPEN_SOURCE 700

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    const char *ruta = argc == 2 ? argv[1] : "archivo";
    int fd = open(ruta, O_RDWR | O_CREAT, 0666);

    if (fd == -1) {
        perror("open");
        return EXIT_FAILURE;
    }
    if (ftruncate(fd, 100) == -1) {
        perror("ftruncate");
        close(fd);
        return EXIT_FAILURE;
    }
    if (lseek(fd, 0, SEEK_SET) == (off_t)-1) {
        perror("lseek");
        close(fd);
        return EXIT_FAILURE;
    }

    printf("Proceso %ld: esperando el candado\n", (long)getpid());
    fflush(stdout);
    if (lockf(fd, F_LOCK, 100) == -1) {
        perror("lockf");
        close(fd);
        return EXIT_FAILURE;
    }

    printf("Proceso %ld: candado colocado\n", (long)getpid());
    fflush(stdout);
    sleep(5);
    if (lockf(fd, F_ULOCK, 100) == -1) {
        perror("lockf");
        close(fd);
        return EXIT_FAILURE;
    }
    printf("Proceso %ld: candado eliminado\n", (long)getpid());

    close(fd);
    return EXIT_SUCCESS;
}
