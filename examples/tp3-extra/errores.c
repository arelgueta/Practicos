#include <stdlib.h>

int main() {
    char *buffer = malloc(4);
    buffer[4] = 1;       /* escritura fuera de limites */
    free(buffer);
    free(buffer);        /* liberacion doble */
    return 0;
}
