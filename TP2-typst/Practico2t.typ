#set text(lang: "es")
#set heading(numbering: "1.1")
#set page(header: align(right, text(size: 8pt)[Licenciatura en Ciencias de la Computacion#linebreak()Sistemas Operativos#linebreak()#line(length: 100%, stroke: 0.5pt)]), numbering: "1 / 1")

#let info = x => rect(fill: blue.transparentize(90%), stroke: blue.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *INFO*

  #x
]

#let extra = x => rect(fill: orange.transparentize(90%), stroke: orange.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *EXTRA*

  #x
]

#show raw.where(block: false): x => box(fill: black.transparentize(90%), stroke: black.transparentize(30%), radius: 0.5em, outset: 0.025em, inset: 0.25em, x)
#show raw.where(block: true): x => rect(fill: black.transparentize(90%), stroke: black.transparentize(30%), width: 100%, radius: 0.5em, inset: 0.5em, x)

#align(center + horizon)[
  #text(size: 24pt, weight: "bold")[Trabajo Práctico 2 - Procesos]
  #v(1em)
  #text(size: 14pt, weight: "bold")[SISTEMAS OPERATIVOS]
]

#pagebreak()
#outline()
#pagebreak()

= Estados y observación de procesos

Un proceso es un programa que está corriendo. Cada proceso tiene un identificador único, llamado PID, y normalmente mantiene una relación con el proceso que lo creó. El identificador de ese proceso padre se llama PPID.

Con `ps` ("Process Snapshot") podés ver procesos. Sin opciones muestra los procesos asociados a la terminal actual:

```sh
$ ps
```

Cada vez que ejecutás `ps`, el shell crea un proceso nuevo, por eso su PID cambia. El shell, en cambio, sigue corriendo y conserva su PID.

Para ver más información y listar procesos de todos los usuarios, probá:

```sh
$ ps aux
$ ps -fu "$USER"
$ pstree -p
```

La opción `f` muestra las relaciones padre-hijo como un árbol. Con `-T -p PID` podés ver los hilos de un proceso:

```sh
$ ps -T -p 1234
```

#info[Consultá opciones disponibles con `man ps`. Para salir de visores interactivos, apretá `q`.]

== Comando `top`

Con `top` podés ver procesos ordenados por consumo de recursos. La lista se actualiza periódicamente y el orden puede cambiar porque planificador selecciona procesos según prioridad dinámica.

```sh
$ top
$ top -H
```

Opción `-H` muestra hilos. También podés usar `htop`, que ofrece una interfaz interactiva más cómoda.

= El sistema de archivos `/proc`

`/proc` es un sistema de archivos virtual que genera núcleo. No representa dispositivo de almacenamiento: sirve para consultar información sobre procesos, memoria, CPU y otras partes del sistema.

Hay un directorio numérico por cada proceso activo. Enlace `/proc/self` apunta al proceso que lo está consultando:

```sh
$ ls -l /proc/self
lrwxrwxrwx 1 root root 0 ... /proc/self -> 4856
$ ls -l /proc/self
lrwxrwxrwx 1 root root 0 ... /proc/self -> 4857
```

Dentro de cada directorio de proceso hay archivos como `status`. Ahí podés encontrar estado, PID, PPID y cambios de contexto:

```sh
$ grep ctxt /proc/self/status
voluntary_ctxt_switches: 0
nonvoluntary_ctxt_switches: 2
```

#extra[También podés explorar `/proc/cpuinfo`, `/proc/meminfo` y `/proc/interrupts`. Compará esa información con salida de comandos del sistema.]

= PID y proceso padre

POSIX ofrece llamadas al sistema para consultar identidad de proceso. Las funciones que vamos a usar son:

```c
pid_t getpid(void);
pid_t getppid(void);
```

Creá archivo `obtenerpid.c` con este contenido:

#raw(read("../examples/tp2/processes/obtenerpid.c"), lang: "c", block: true)

Compilalo y ejecutalo:

```sh
$ gcc -Wall -Wextra -o obtenerpid obtenerpid.c
$ ./obtenerpid
PID: 7014
PPID: 3814
$ strace ./obtenerpid
```

#extra[
  Investigá qué hacen las opciones `-Wall` y `-Wextra`. Podés consultar `man gcc` o buscar la documentación online. Después, compilá el programa con y sin esas opciones y compará los mensajes del compilador.
]

El PPID normalmente corresponde al shell que lanzó programa. Con `strace` podés ver llamadas al sistema durante ejecución.

= Creación de procesos: `fork()` y `exec()`

`fork()` crea proceso hijo como copia del proceso que lo invoca. Su retorno te permite distinguir caminos: `-1` indica error, `0` identifica hijo y valor positivo identifica padre.

#raw(read("../examples/tp2/processes/creaproceso.c"), lang: "c", block: true)

```sh
$ gcc -Wall -Wextra -o creaproceso creaproceso.c
$ ./creaproceso
Padre: PID=7094 PPID=3814
Hijo: PID=7095 PPID=7094
$ strace -f ./creaproceso
```

La llamada `exec()` reemplaza programa que está corriendo por otro. Shell suele crear hijo con `fork()` y después cargar ahí comando pedido mediante variante de `exec()`.

= Hilos POSIX

Los hilos te permiten ejecutar varias secuencias dentro del mismo proceso. Comparten memoria, pero cada uno tiene estado de ejecución propio.

#raw(read("../examples/tp2/processes/holahilo.c"), lang: "c", block: true)

Compilalo enlazando biblioteca POSIX de hilos. Para detenerlo, apretá `Ctrl-C`:

```sh
$ gcc -Wall -Wextra -pthread -o holahilo holahilo.c
$ ./holahilo
Hola
mundo
...
```

#extra[Compará salida de `ps -T -p PID` antes y después de crear hilos. Repetí pruebas con `strace -f` y fijate qué cambia entre procesos e hilos.]
