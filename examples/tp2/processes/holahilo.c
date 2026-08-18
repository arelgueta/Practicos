#include <pthread.h>
#include <stdio.h>

void *saludar(void *arg) {
    const char *texto = arg;
    while (1) printf("%s\n", texto);
    return NULL;
}

int main() {
    pthread_t uno, dos;
    pthread_create(&uno, NULL, saludar, "Hola");
    pthread_create(&dos, NULL, saludar, "mundo");
    pthread_join(uno, NULL);
    pthread_join(dos, NULL);
    return 0;
}
