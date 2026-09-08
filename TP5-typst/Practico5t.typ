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

Este TP estudia cómo coordinar hilos y procesos que comparten estado o
intercambian datos. Vas a observar una condición de carrera, corregirla con
exclusión mutua, construir un buffer acotado, conectar procesos con una
tubería y administrar recursos compartidos. Los tiempos, órdenes y salidas
dependen de la carga y de la cantidad de núcleos: registrá tus observaciones
en lugar de copiar una salida de ejemplo.

= Condición de carrera y sección crítica

Una condición de carrera (*race condition*) aparece cuando el resultado depende
del orden en que hilos o procesos acceden a un estado compartido. Una sección
crítica es la parte que debe ejecutarse con acceso exclusivo. La operación
"incrementar un contador" no tiene por qué ser indivisible: puede leer,
modificar y escribir en pasos separados.

Copiá el siguiente listado en un archivo local llamado `contador.c`, o
implementá la misma interfaz y comportamiento en otro lenguaje. El programa
crea trabajadores que actualizan un contador y ofrece una versión sin
protección y otra con un mutex (objeto de exclusión mutua, *mutual
exclusion*):

#raw(read("../examples/tp5/contador.c"), lang: "c")

Compilá las dos variantes de la implementación de referencia:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread contador.c -o contador-inseguro
$ ./contador-inseguro
$ gcc -Wall -Wextra -O0 -g -pthread -DUSE_MUTEX contador.c -o contador
$ ./contador
```

El modo no protegido puede acertar ocasionalmente; eso no demuestra que sea
correcto. Repetí cada prueba varias veces y compará en la consola el modo, el
valor esperado y el valor observado. Los valores de `THREADS` e `ITERATIONS`
están definidos al comienzo del listado: cambialos para estudiar cómo afectan
el resultado.

Considerá durante la ejecución:

1. qué intercalado permite que se pierda una actualización;
2. qué parte del programa es la sección crítica;
3. por qué el mutex corrige el resultado y qué costo observable agrega;
4. si la ejecución cumple exclusión mutua, progreso y espera limitada.

#extra[
  Si querés profundizar, repetí el experimento acumulando primero un contador
  local en cada trabajador y sumando esos resultados una sola vez al final.
  Considerá por qué reduce la contención y por qué no es una solución general
  para cualquier estado compartido.
]

= Variables de condición y productor-consumidor

Un buffer de capacidad finita necesita coordinar dos situaciones: un productor
debe esperar cuando está lleno y un consumidor debe esperar cuando está vacío.
Una variable de condición permite dormir el hilo hasta que cambie el estado
relevante. Siempre se usa junto con un mutex y una condición `while`; la
variable de condición no protege los datos por sí sola.

Copiá el siguiente listado en un archivo local llamado `buffer.c`, o
implementá la misma interfaz y comportamiento en otro lenguaje. Un productor
agrega una cantidad finita de elementos y un consumidor los retira. El programa
termina cuando el productor finalizó y el buffer quedó vacío:

#raw(read("../examples/tp5/buffer.c"), lang: "c")

Compilá y ejecutá:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread buffer.c -o buffer
$ ./buffer
```

Observá que se consuman todos los elementos. Cambiá `CAPACITY` e `ITEMS`,
recompilá y repetí. Considerá qué ocurre si se reemplaza `while` por `if`, o si
se consulta el estado del buffer sin tomar el mutex.

Considerá la relación del programa con productor-consumidor y con la idea de
monitor: un estado privado al que se accede mediante operaciones que mantienen
la exclusión mutua. Compará la espera bloqueante con un loop que consulta
continuamente si hay espacio o elementos.

= Tuberías, descriptores y fin de archivo

Una tubería anónima es un canal unidireccional que el núcleo mantiene para que
un proceso escriba y otro lea. El lanzador del siguiente ejemplo recrea una
parte de lo que hacen los shells al usar el operador `|`: crea dos hijos,
conecta sus descriptores estándar y espera a ambos.

Copiá el siguiente listado en un archivo local llamado `pipeline.c`, o
implementá la misma interfaz y comportamiento en otro lenguaje:

#raw(read("../examples/tp5/pipeline.c"), lang: "c")

Compilá y compará la salida con la que produce el shell:

```bash
$ gcc -Wall -Wextra -O0 -g pipeline.c -o pipeline
$ printf 'uno\ndos\ntres\n' | wc -l
$ ./pipeline
```

Considerá el papel de `pipe`, `fork`, `dup2`, `execlp` y `waitpid`, y por qué
cada proceso debe cerrar los extremos que no usa. En particular, el lector
puede quedar bloqueado si algún proceso conserva abierto un descriptor de
escritura, aun cuando ya no vaya a escribir.

#info[
  Los descriptores 0, 1 y 2 son, respectivamente, entrada estándar, salida
  estándar y error estándar. La salida de datos puede redirigirse a la
  tubería, pero los diagnósticos deben conservarse en `stderr`.
]

#extra[
  Compará la tubería anónima con una tubería con nombre FIFO (*First In, First
  Out*). En un directorio temporal, abrí una terminal con:

  ```bash
  $ mkfifo canal
  $ wc -l < canal
  ```

  Y otra con:

  ```bash
  $ printf '%s\n' uno dos tres > canal
  ```

  El lector espera hasta que aparece un escritor y termina al recibir EOF
  cuando el escritor cierra la FIFO. Compará herencia de descriptores, nombre,
  bloqueo, dirección y duración. Eliminá el archivo especial con `rm canal` al
  terminar.
]

= Semáforos entre procesos

Un semáforo permite coordinar el acceso a un recurso sin transportar los datos
del recurso. En este ejercicio usaremos un semáforo binario System V entre
procesos creados con `fork`. La operación negativa espera y decrementa el
valor; la operación positiva lo incrementa y puede despertar a otro proceso.
Ambas operaciones son indivisibles para el conjunto administrado por el
núcleo.

Copiá el siguiente listado en un archivo local llamado `sem-sync.c`, o
implementá la misma interfaz y comportamiento en otro lenguaje:

#raw(read("../examples/tp5/sem-sync.c"), lang: "c")

El recorrido importante es:

```c
semget(IPC_PRIVATE, 1, 0600);
semctl(semid, 0, SETVAL, inicial);
semop(semid, &adquirir, 1);  /* sem_op = -1 */
semop(semid, &liberar, 1);   /* sem_op = +1 */
semctl(semid, 0, IPC_RMID);
```

Compilá y ejecutá:

```bash
$ gcc -Wall -Wextra -O0 -g sem-sync.c -o sem-sync
$ ./sem-sync
```

El programa informa el identificador del conjunto y muestra qué proceso
adquirió el semáforo. Consultá `ipcs -s` desde otra terminal mientras el
programa está activo y observá que al finalizar imprime que eliminó el
identificador. Los IDs y el orden de los procesos cambian en cada ejecución.

Considerá durante la ejecución:

1. por qué sólo un proceso imprime que está dentro de la sección crítica al
   mismo tiempo;
2. qué ocurriría si el proceso terminara sin liberar el semáforo;
3. qué diferencia hay entre un semáforo binario y uno con un contador positivo
   mayor que uno;
4. qué recurso queda en el sistema si se omite `IPC_RMID`.

#note[
  `IPC_PRIVATE` no significa que el recurso desaparezca al terminar el proceso
  creador: indica que se debe crear un conjunto nuevo. Si una prueba se
  interrumpe, localizá únicamente el `semid` que creó tu programa y usá
  `ipcrm -s semid`. No elimines semáforos de otros usuarios.
]

= Bloqueos de archivo y `/proc/locks`

Un bloqueo de archivo asesorado (*advisory lock*) sólo coordina a los procesos
que respetan el mismo protocolo. No impide que un proceso que ignora el bloqueo
escriba el archivo. `lockf` permite bloquear una región respecto de la posición
actual del descriptor; en Linux se relaciona con los bloqueos de registros de
`fcntl`.

Copiá el siguiente listado en un archivo local llamado `lock-counter.c`, o
implementá la misma interfaz y comportamiento en otro lenguaje. El programa
crea varios procesos que realizan una operación de lectura-modificación-
escritura sobre el mismo contador:

#raw(read("../examples/tp5/lock-counter.c"), lang: "c")

Compará ambos modos:

```bash
$ gcc -Wall -Wextra -O0 -g lock-counter.c -o lock-counter-inseguro
$ ./lock-counter-inseguro
$ gcc -Wall -Wextra -O0 -g -DUSE_LOCK lock-counter.c -o lock-counter
$ ./lock-counter
```

El valor esperado es `WORKERS * ROUNDS`. Repetí con más rondas cambiando la
constante `ROUNDS` del listado y, mientras una ejecución con `USE_LOCK` está
activa, observá `/proc/locks` desde otra terminal:

```bash
$ cat /proc/locks
```

Observá el valor final, el tipo de bloqueo, el PID y la región observada.
Considerá por qué la versión sin bloqueo puede perder actualizaciones y por
qué un proceso que no llama a `lockf` puede ignorar el bloqueo asesorado.

= Interbloqueo: provocar, diagnosticar y evitar

Un interbloqueo (*deadlock*) ocurre cuando un conjunto de tareas queda
esperando recursos que sólo pueden liberar tareas del mismo conjunto. En el
ejemplo, dos hilos adquieren dos mutexes en órdenes opuestos.

#raw(read("../examples/tp5/deadlock.c"), lang: "c")

Compilá y ejecutá primero la versión que puede quedar bloqueada:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread deadlock.c -o deadlock
$ timeout 3 ./deadlock
```

Después recompilá imponiendo un orden global y ejecutá la versión segura:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread -DSAFE_ORDER deadlock.c -o deadlock-safe
$ ./deadlock-safe
```

La salida debe mostrar que cada hilo tomó un recurso y espera el otro. El
comando `timeout` evita dejar la terminal bloqueada; no ejecutes el programa
sobre procesos del sistema.

Considerá las cuatro condiciones de Coffman:

- exclusión mutua;
- retención y espera;
- no expropiación;
- espera circular.

Considerá por qué el orden global rompe la espera circular, la diferencia entre
interbloqueo, inanición y espera activa, y qué cambiaría si el programa usara
`pthread_mutex_trylock` para retirarse y reintentar.

#extra[
  Si querés profundizar, considerá el grafo de espera de la ejecución
  bloqueada: cada hilo es un nodo y cada flecha indica el recurso que espera.
  Incluí la adquisición del primer recurso y observá dónde aparece el ciclo.
]
