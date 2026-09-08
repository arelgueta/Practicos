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

#let note = x => rect(fill: black.transparentize(93%), stroke: black.transparentize(35%), radius: 0.75em, width: 100%, inset: 1em)[
  #x
]

#show raw.where(block: false): x => box(fill: black.transparentize(90%), stroke: black.transparentize(30%), radius: 0.5em, outset: 0.025em, inset: 0.25em, x)
#show raw.where(block: true): x => {
  v(0.25em)
  rect(fill: black.transparentize(90%), stroke: black.transparentize(30%), width: 100%, radius: 0.5em, inset: 0.5em, x)
  v(0.25em)
}

#align(center + horizon)[
  #text(size: 24pt, weight: "bold")[Trabajo Práctico 5 - Sincronización]
  #v(1em)
  #text(size: 14pt, weight: "bold")[SISTEMAS OPERATIVOS]
]

#pagebreak()
#outline()
#pagebreak()

En este TP vas a estudiar cómo cooperan los procesos cuando deben comunicarse
o coordinar el acceso a un recurso compartido. Vamos a usar llamadas POSIX
(Portable Operating System Interface) para construir una tubería, candados de
archivos y semáforos de System V. En todos los casos, observá primero qué hace
el núcleo y después relacioná el resultado con los descriptores, los procesos y
sus estados.

= Comunicación entre procesos con tuberías

Una tubería o *pipe* es un canal unidireccional de comunicación entre procesos.
Un proceso escribe una secuencia de bytes en un extremo y otro proceso la lee
del extremo opuesto. Por ejemplo, el shell puede conectar `ls` con `wc` mediante
el carácter `|`:

```bash
$ ls | wc
```

`wc` (*word count*) muestra, por defecto, la cantidad de líneas, palabras y
bytes que recibió. El shell no copia esos datos a mano: crea un pipe, conecta
los descriptores estándar de cada proceso y luego ejecuta los programas.

== Descriptores de archivo

Un descriptor de archivo es un número entero que identifica, dentro de un
proceso, un archivo o canal abierto. Cada proceso comienza normalmente con
tres descriptores estándar:

#table(
  columns: (auto, 1fr, 1.5fr),
  inset: 6pt,
  stroke: 0.5pt + gray,
  [*Valor*], [*Nombre*], [*Constante en C*],
  [`0`], [Entrada estándar (`stdin`)], [`STDIN_FILENO`],
  [`1`], [Salida estándar (`stdout`)], [`STDOUT_FILENO`],
  [`2`], [Error estándar (`stderr`)], [`STDERR_FILENO`],
)

La llamada `pipe(fd)` recibe un arreglo de dos enteros. Si tiene éxito,
`fd[0]` es el extremo de lectura y `fd[1]` el extremo de escritura. Un pipe
anónimo no tiene un nombre en el sistema de archivos: los procesos pueden
usarlo si heredan sus descriptores, normalmente después de un `fork()`. Una
FIFO (*First In, First Out*), en cambio, tiene un nombre y permite que procesos
no relacionados la abran mediante ese nombre.

#note[
  Un pipe no es un archivo temporal. El núcleo mantiene un búfer para el canal
  y entrega los bytes en el mismo orden en que fueron escritos. Si no queda
  ningún descriptor de escritura abierto, una lectura puede observar fin de
  archivo; si el búfer está vacío pero todavía existe un escritor, la lectura
  espera.
]

== Construir `ls | wc`

El siguiente programa crea dos hijos. El primero ejecuta `ls` y redirige su
salida al pipe; el segundo ejecuta `wc` y redirige su entrada desde el pipe. El
proceso original cierra sus copias de ambos extremos y espera a los dos hijos.

#raw(read("../examples/tp5/tuberia.c"), lang: "c", block: true)

Compilá y ejecutá el programa. La salida puede variar según los archivos del
directorio actual:

```bash
$ gcc -Wall -Wextra -std=c11 -o tuberia tuberia.c
$ ./tuberia
      8      8     74
```

Los números mostrados son sólo un ejemplo. Probá también la versión del shell
y compará las dos ejecuciones:

```bash
$ ls | wc
$ strace -f -e trace=pipe,pipe2,dup2,close,execve,wait4 ./tuberia
```

En el hijo que ejecuta `ls`, `dup2(fd[1], STDOUT_FILENO)` hace que el descriptor
1 apunte al extremo de escritura. En el otro hijo, la misma operación hace que
el descriptor 0 apunte al extremo de lectura. Después de duplicar, cada
proceso cierra los descriptores que ya no necesita. Esos `close()` no son un
detalle decorativo: un descriptor de escritura olvidado puede impedir que `wc`
vea el fin de archivo.

1. Dibujá el pipe y marcá qué proceso conserva cada extremo después de los
   cierres. Indicá qué representan los descriptores 0 y 1 en cada hijo.
2. Explicá por qué el programa crea dos hijos en vez de ejecutar `wc`
   directamente en el proceso original.
3. Agregá una tercera etapa para construir una cadena equivalente a
   `ls | wc -l | cat`. ¿Qué extremos debe cerrar cada proceso?
4. Consultá `/proc/<pid>/fd` mientras un proceso permanece bloqueado en una
   lectura. Relacioná los enlaces simbólicos con los descriptores del programa.

= Tuberías con nombre: `mkfifo`

Una FIFO tiene una entrada permanente en un directorio y puede ser abierta por
procesos que no tienen un ancestro común. El nombre no contiene los datos: sólo
permite que los procesos encuentren el mismo canal del núcleo. Abrirla para leer
o escribir puede bloquearse hasta que exista un proceso en el extremo opuesto.

Probala desde dos terminales. En la primera terminal creá la FIFO y dejá un
lector esperando:

```bash
$ mkfifo canal
$ ls -l canal
$ cat < canal
```

En la segunda terminal escribí un mensaje y observá que `cat` termina cuando
recibe el fin de archivo:

```bash
$ printf 'mensaje enviado por una FIFO\n' > canal
```

La entrada `canal` permanece en el directorio aunque los procesos hayan
terminado. Eliminála cuando finalices la prueba:

```bash
$ rm canal
```

Repetí la prueba con `echo`, `wc` o dos programas propios. Compará la FIFO con
el pipe anónimo del programa anterior: ¿qué propiedad permite que la usen
procesos que no tienen un ancestro común?

#extra[
  Como extensión, inspeccioná los descriptores de los procesos mientras la FIFO
  está abierta con `ls -l /proc/<pid>/fd`. Relacioná los enlaces simbólicos con
  el nombre `canal` y con el estado bloqueado de la operación de apertura.
]

= Exclusión mutua con candados de archivos

Cuando varios procesos acceden al mismo recurso, una operación puede necesitar
exclusión mutua: mientras un proceso está en su sección crítica, los demás deben
esperar. Sin coordinación, dos procesos pueden leer el mismo estado, calcular
resultados incompatibles y sobrescribir los cambios del otro.

`lockf()` permite solicitar un candado exclusivo sobre una región de un archivo
abierto. El tamaño se cuenta desde la posición actual del descriptor. Las
operaciones principales son:

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt + gray,
  [*Operación*], [*Comportamiento*],
  [`F_ULOCK`], [libera el candado de la región],
  [`F_LOCK`], [solicita el candado y espera si la región está ocupada],
  [`F_TLOCK`], [solicita el candado y falla inmediatamente si está ocupado],
  [`F_TEST`], [comprueba si la región está disponible, sin tomarla],
)

Estos candados son normalmente *advisory*: el núcleo coordina a los procesos
que también intentan adquirir el candado, pero no impide que un programa que lo
ignora escriba el archivo. El candado se libera al ejecutar `F_ULOCK` o cuando
el proceso cierra el archivo o termina.

== Un candado bloqueante

El ejemplo toma el candado de los primeros 100 bytes durante cinco segundos.
El argumento opcional permite que varias copias usen el mismo archivo. La
llamada a `ftruncate()` deja preparada la región, y `lseek()` coloca la
posición al comienzo antes de llamar a `lockf()`.

#raw(read("../examples/tp5/candado.c"), lang: "c", block: true)

Compilalo y ejecutá primero una sola copia:

```bash
$ gcc -Wall -Wextra -std=c11 -o candado candado.c
$ ./candado archivo.bin
Proceso 2659: esperando el candado
Proceso 2659: candado colocado
Proceso 2659: candado eliminado
```

Después iniciá tres copias sobre el mismo archivo y esperá a que todas
terminen:

```bash
$ ./candado archivo.bin & p1=$!
$ ./candado archivo.bin & p2=$!
$ ./candado archivo.bin & p3=$!
$ wait "$p1" "$p2" "$p3"
```

Sólo un proceso debería mostrar *candado colocado* a la vez. El orden de
adquisición no tiene por qué coincidir con el orden de lanzamiento ni con el
valor de los PID. Mientras el experimento está corriendo, observá
`/proc/locks` desde otra terminal:

```bash
$ cat /proc/locks
```

Una línea puede indicar la clase del candado (por ejemplo, `POSIX`), si es
asesor o obligatorio, el modo de acceso, el PID, el dispositivo e inode y los
límites de la región. La representación y la cantidad de líneas dependen de la
versión del núcleo y de los demás procesos del sistema.

1. Registrá para cada copia el PID, el instante en que empezó a esperar, el
   instante en que obtuvo el candado y el instante en que lo liberó.
2. ¿Qué proceso entra primero? ¿Podés deducir una política de planificación a
   partir de ese orden? Justificá la respuesta.
3. Cambiá `F_LOCK` por `F_TLOCK`. ¿Qué diferencia observás y qué código de
   error deberías tratar en un programa real?
4. ¿Por qué este mecanismo no evita que un programa que use `write()` sin
   llamar a `lockf()` modifique el archivo?

#extra[
  Investigá `flock()` y los candados POSIX de `fcntl()`. Compará qué objetos
  identifican, qué ocurre al duplicar un descriptor y si los candados son
  heredados después de `fork()`. Consultá las páginas de manual de `flock(2)`,
  `fcntl(2)` y `lockf(3)`; no modifiques archivos del sistema.
]

= Semáforos de System V

Un semáforo es un contador mantenido por el núcleo para coordinar el acceso a
un recurso. En el caso binario, el valor 1 puede representar "disponible" y el
valor 0 "ocupado". La operación de espera decrementa el contador y se bloquea
si no puede hacerlo; la operación de señal lo incrementa cuando el proceso
libera el recurso. A diferencia de un pipe, el semáforo no transporta datos:
sólo sincroniza.

En este apartado usaremos la interfaz de IPC (*Inter-Process Communication*)
de System V:

- `semget()` crea un conjunto de semáforos o devuelve el identificador de uno
  existente;
- `semop()` aplica una o más operaciones atómicas descritas por estructuras
  `sembuf`;
- `semctl()` consulta, modifica o elimina el conjunto.

== Permisos del conjunto

Los permisos de un semáforo de System V se aplican al conjunto completo y
siguen el esquema de propietario, grupo y otros usuarios. Sus nombres no son
"lectura" y "escritura", sino lectura y alteración: no hay datos que leer o
escribir como en un archivo.

- El permiso de lectura permite consultar valores y metadatos, por ejemplo con
  `GETVAL`, `GETALL` o `IPC_STAT`.
- El permiso de alteración permite cambiar valores con `semop()`, `SETVAL` o
  `SETALL`.
- `IPC_SET` e `IPC_RMID` requieren ser propietario o creador del conjunto, o
  tener privilegios suficientes.

Por ejemplo, `0660` permite leer y alterar el conjunto al propietario y al
grupo, pero no da acceso a otros usuarios. En la columna `perms` de `ipcs -s`,
el bit que en un archivo se suele llamar "escritura" representa aquí
alteración.

Una estructura `sembuf` indica el índice del semáforo, el cambio que se quiere
hacer en `sem_op` y opciones como `IPC_NOWAIT`. Una operación positiva
incrementa el valor; una operación negativa espera hasta que haya suficiente
valor y luego lo decrementa. Una operación cero espera hasta que el valor llegue
a cero.

== Crear e inicializar un semáforo

El programa siguiente solicita un conjunto con un semáforo usando
`IPC_PRIVATE`. En este contexto, esa constante no significa que el semáforo sea
sólo del proceso: indica a `semget()` que debe crear un nuevo conjunto. El
programa incrementa el semáforo a 1 y deja el conjunto existente para que puedas
inspeccionarlo y eliminarlo en el paso siguiente.

#raw(read("../examples/tp5/creasem.c"), lang: "c", block: true)

Compilá y compará la lista de semáforos antes y después de ejecutar:

```bash
$ gcc -Wall -Wextra -std=c11 -o creasem creasem.c
$ gcc -Wall -Wextra -std=c11 -o cntrlsem cntrlsem.c
$ ipcs -s
$ ./creasem
Semaforo creado: 98307
Su valor inicial es 1 (recurso disponible).
Eliminalo con: ./cntrlsem 98307
$ ipcs -s
```

El identificador del ejemplo cambia en cada ejecución. Guardá el valor que
imprima tu sistema; no copies `98307`. Observá las columnas de `ipcs`: clave,
identificador, propietario, permisos y cantidad de semáforos del conjunto.

== Consultar y eliminar el conjunto

El comando `semctl()` recibe el identificador del conjunto y el índice del
semáforo. En este TP usamos un conjunto de un elemento, por eso el índice es
siempre cero. Algunas operaciones útiles son:

#table(
  columns: (auto, 1fr),
  inset: 6pt,
  stroke: 0.5pt + gray,
  [*Comando*], [*Efecto*],
  [`GETVAL`], [devuelve el valor actual del semáforo],
  [`SETVAL`], [establece el valor indicado por el argumento],
  [`GETPID`], [devuelve el PID del último proceso que ejecutó `semop()`],
  [`GETNCNT`], [devuelve cuántos procesos esperan que el valor aumente],
  [`GETZCNT`], [devuelve cuántos procesos esperan que el valor sea cero],
  [`GETALL`], [devuelve los valores de todos los semáforos del conjunto],
  [`SETALL`], [establece los valores de todos los semáforos del conjunto],
  [`IPC_SET`], [modifica propietario, grupo y permisos del conjunto],
  [`IPC_STAT`], [copia la configuración del conjunto a una estructura `semid_ds`],
  [`IPC_RMID`], [elimina el conjunto de semáforos],
)

`GETALL` y `SETALL` usan un arreglo dentro del argumento de `semctl()`;
`IPC_STAT` y `IPC_SET` usan una estructura `semid_ds`. En todos los casos, el
proceso debe tener los permisos necesarios para consultar o modificar el
conjunto.

El programa de control usa `IPC_RMID`:

#raw(read("../examples/tp5/cntrlsem.c"), lang: "c", block: true)

Pasale el identificador que imprimió `creasem` y verificá que ya no aparezca
en `ipcs -s`:

```bash
$ ./cntrlsem 98307
Semaforo eliminado.
$ ipcs -s
```

Si cerraste la terminal antes de eliminar el conjunto, todavía podés quitarlo
con `ipcrm -s SEMID`, siempre que tengas permisos. Los semáforos de System V
son recursos persistentes del núcleo: terminar el programa creador no los
elimina automáticamente.

1. Ejecutá `creasem` dos veces sin eliminar los conjuntos. ¿Cuántas entradas
   nuevas aparecen y por qué `IPC_PRIVATE` no hace que ambas ejecuciones
   compartan el mismo conjunto?
2. Eliminá los dos conjuntos y repetí la observación con `ipcs -s`. ¿Qué
   diferencia hay entre el valor del semáforo y el identificador del conjunto?
3. Relacioná la operación negativa de `semop()` con la espera bloqueante de
   `lockf(F_LOCK)`. ¿Qué tienen en común y qué no protegen por sí solos?
4. Consultá `/proc/sysvipc/sem` y compará su información con `ipcs -s`.
