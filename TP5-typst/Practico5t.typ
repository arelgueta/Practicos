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

La implementación de referencia en C está en
`../examples/tp5/contador.c`. Si usás otro lenguaje, conservá la misma
interfaz y comportamiento. El programa crea trabajadores que actualizan un
contador y ofrece una versión sin protección y otra con un mutex (objeto de
exclusión mutua, *mutual exclusion*):

#raw(read("../examples/tp5/contador.c"), lang: "c")

Compilá y probá la implementación de referencia:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread ../examples/tp5/contador.c -o contador
$ ./contador --threads 4 --iterations 100000 --unsafe --yield
$ ./contador --threads 4 --iterations 100000 --mutex --yield
```

El modo no protegido puede acertar ocasionalmente; eso no demuestra que sea
correcto. Repetí cada prueba varias veces y registrá una tabla con cantidad de
hilos, iteraciones, modo, valor esperado, valor observado y tiempo. Compará
también una ejecución con y sin `--yield`.

Contestá:

1. Qué intercalado permite que se pierda una actualización?
2. Qué parte del programa es la sección crítica?
3. Por qué el mutex corrige el resultado y qué costo observable agrega?
4. La ejecución cumple exclusión mutua, progreso y espera limitada?

#extra[
  Repetí el experimento acumulando primero un contador local en cada trabajador
  y sumando esos resultados una sola vez al final. Explicá por qué reduce la
  contención y por qué no es una solución general para cualquier estado
  compartido.
]

= Variables de condición y productor-consumidor

Un buffer de capacidad finita necesita coordinar dos situaciones: un productor
debe esperar cuando está lleno y un consumidor debe esperar cuando está vacío.
Una variable de condición permite dormir el hilo hasta que cambie el estado
relevante. Siempre se usa junto con un mutex y una condición `while`; la
variable de condición no protege los datos por sí sola.

La implementación de referencia en C está en
`../examples/tp5/buffer.c`. Cada productor agrega una cantidad finita de
elementos y cada consumidor los retira. El programa termina cuando todos los
productores finalizaron y el buffer quedó vacío:

#raw(read("../examples/tp5/buffer.c"), lang: "c")

Compilá y ejecutá con distintas capacidades:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread ../examples/tp5/buffer.c -o buffer
$ ./buffer --producers 2 --consumers 2 --items 1000 --capacity 4
$ ./buffer --producers 3 --consumers 1 --items 1000 --capacity 32
```

Verificá que la cantidad consumida, la suma de secuencias y los elementos
restantes coincidan con lo esperado. Explicá qué ocurre si se reemplaza
`while` por `if`, o si se consulta el estado del buffer sin tomar el mutex.

Relacioná este programa con el problema clásico del productor-consumidor y con
la idea de monitor: un estado privado al que se accede mediante operaciones que
mantienen la exclusión mutua. Compará la espera bloqueante con un loop que
consulta continuamente si hay espacio o elementos.

= Tuberías, descriptores y fin de archivo

Una tubería anónima es un canal unidireccional que el núcleo mantiene para que
un proceso escriba y otro lea. El lanzador del siguiente ejemplo recrea una
parte de lo que hace el shell con el operador `|`: crea dos hijos, conecta sus
descriptores estándar y espera a ambos.

La implementación de referencia en C está en
`../examples/tp5/pipeline.c`:

#raw(read("../examples/tp5/pipeline.c"), lang: "c")

Compilá y compará las dos formas de ejecutar el mismo flujo:

```bash
$ gcc -Wall -Wextra -O0 -g ../examples/tp5/pipeline.c -o pipeline
$ printf 'uno\ndos\ntres\n' | wc -l
$ ./pipeline printf 'uno\ndos\ntres\n' -- wc -l
```

Identificá el papel de `pipe`, `fork`, `dup2`, `execvp` y `waitpid`. Explicá
por qué cada proceso debe cerrar los extremos que no usa. En particular, el
lector puede quedar bloqueado si algún proceso conserva abierto un descriptor
de escritura, aun cuando ya no vaya a escribir.

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

La implementación de referencia en C está en
`../examples/tp5/sem-sync.c`:

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
$ gcc -Wall -Wextra -O0 -g ../examples/tp5/sem-sync.c -o sem-sync
$ ./sem-sync --workers 3 --hold-ms 200
$ ipcs -s
```

El programa informa el identificador del conjunto y muestra qué proceso
adquirió el semáforo. Consultá `ipcs -s` mientras el programa está activo y
verificá que al finalizar imprime que eliminó el identificador. Los IDs y el
orden de los procesos cambian en cada ejecución.

Contestá:

1. Por qué sólo un proceso imprime que está dentro de la sección crítica al
   mismo tiempo?
2. Qué ocurriría si el proceso terminara sin liberar el semáforo?
3. Qué diferencia hay entre un semáforo binario y uno con un contador positivo
   mayor que uno?
4. Qué recurso queda en el sistema si se omite `IPC_RMID`?

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

La implementación de referencia en C crea varios procesos que realizan una
operación de lectura-modificación-escritura sobre el mismo contador:

#raw(read("../examples/tp5/lock-counter.c"), lang: "c")

Usá un archivo temporal y compará ambos modos:

```bash
$ gcc -Wall -Wextra -O0 -g ../examples/tp5/lock-counter.c -o lock-counter
$ work=$(mktemp -d)
$ ./lock-counter --file "$work/counter" --workers 3 --rounds 100 --unsafe
$ ./lock-counter --file "$work/counter" --workers 3 --rounds 100 --lock
```

El valor esperado es `workers * rounds`. Repetí con más rondas y, mientras una
ejecución con `--lock` está activa, observá `/proc/locks` desde otra terminal:

```bash
$ cat /proc/locks
$ wait
$ rm -rf "$work"
```

Registrá el valor final, el tipo de bloqueo, el PID y la región observada.
Explicá por qué la versión sin bloqueo puede perder actualizaciones y por qué
un proceso que no llama a `lockf` puede ignorar el bloqueo asesorado.

= Interbloqueo: provocar, diagnosticar y evitar

Un interbloqueo (*deadlock*) ocurre cuando un conjunto de tareas queda
esperando recursos que sólo pueden liberar tareas del mismo conjunto. En el
ejemplo, dos hilos adquieren dos mutexes en órdenes opuestos.

#raw(read("../examples/tp5/deadlock.c"), lang: "c")

Compilá y ejecutá primero la versión que impone un orden global:

```bash
$ gcc -Wall -Wextra -O0 -g -pthread ../examples/tp5/deadlock.c -o deadlock
$ ./deadlock --ordered
```

Después ejecutá el caso intencionalmente bloqueado con un límite:

```bash
$ timeout 3 ./deadlock --deadlock
```

La salida debe mostrar que cada hilo tomó un recurso y espera el otro. El
comando `timeout` evita dejar la terminal bloqueada; no ejecutes el programa
sobre procesos del sistema.

Identificá las cuatro condiciones de Coffman:

- exclusión mutua;
- retención y espera;
- no expropiación;
- espera circular.

Explicá por qué el orden global rompe la espera circular. Diferenciá
interbloqueo, inanición y espera activa, y describí qué cambiaría si el
programa usara `pthread_mutex_trylock` para retirarse y reintentar.

#extra[
  Dibujá el grafo de espera de la ejecución bloqueada: cada hilo es un nodo y
  cada flecha indica el recurso que espera. Agregá la adquisición del primer
  recurso y verificá dónde aparece el ciclo.
]
