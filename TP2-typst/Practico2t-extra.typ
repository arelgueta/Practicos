#set text(lang: "es")
#set heading(numbering: "1.1")
#set page(header: align(right, text(size: 8pt)[Licenciatura en Ciencias de la Computacion#linebreak()Sistemas Operativos#linebreak()#line(length: 100%, stroke: 0.5pt)]), numbering: "1 / 1")

#let track = (difficulty, body) => rect(fill: green.transparentize(90%), stroke: green.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *TRACK - #difficulty*

  #body
]

#let extra = x => rect(fill: orange.transparentize(90%), stroke: orange.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *EXTRA*

  #x
]

#let coin = emoji.coin

#let pointsextra = x => rect(fill: red.transparentize(90%), stroke: red.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *BONUS · POR PUNTOS #coin*

  #x
]

#show raw.where(block: false): x => box(fill: black.transparentize(90%), stroke: black.transparentize(30%), radius: 0.5em, outset: 0.025em, inset: 0.25em, x)
#show raw.where(block: true): x => rect(fill: black.transparentize(90%), stroke: black.transparentize(30%), width: 100%, radius: 0.5em, inset: 0.5em, x)

#align(center + horizon)[
  #text(size: 24pt, weight: "bold")[Trabajo Práctico 2 - Ejercicios extra]
  #v(1em)
  #text(size: 14pt, weight: "bold")[SISTEMAS OPERATIVOS]
]

#pagebreak()
#outline(title: [Tracks])
#pagebreak()

Estos tracks amplían la práctica de procesos con problemas pequeños pero cercanos a herramientas reales. Podés empezar por cualquier track. Cada uno tiene una parte principal y una extensión para seguir investigando.

= Señales y control de trabajos (5/10)

#track("5/10")[
  *Descripción:* usar señales para pausar, continuar y terminar procesos. Es una base práctica para administrar servidores y depurar programas.
]

1. Ejecutar `sleep 100` en foreground y detenerlo con `Ctrl-Z`.
2. Consultar trabajo con `jobs`, continuarlo en background con `bg` y traerlo nuevamente con `fg`.
3. Encontrar PID y enviar `SIGSTOP`, `SIGCONT` y `SIGTERM` usando `kill`.
4. Comparar `SIGTERM` con `SIGKILL`. Explicar por qué un programa no puede capturar `SIGKILL`.
5. Escribir programa que instale handler para `SIGINT`, cuente cuántas veces recibió señal y termine limpiamente con segunda.

#extra[Investigá diferencia entre señal estándar y señal encolada. Usá `kill -l`, `man 7 signal` y `sigaction()`.]

#pagebreak()
= Mini-shell con `fork()` y `exec()` (7/10)

#track("7/10")[
  *Descripción:* construir versión mínima del mecanismo que usa un shell real. Integra parsing, creación de procesos, ejecución y espera.
]

1. Leer línea usando `fgets()` y separar comando de argumentos.
2. Crear hijo con `fork()` y ejecutar comando con `execvp()`.
3. Hacer que padre espere a hijo con `waitpid()`.
4. Implementar comando interno `cd`, que debe ejecutarse en proceso del shell.
5. Agregar ejecución en background cuando línea termina en `&`.
6. Informar errores de `fork()`, `execvp()` y `waitpid()` con `perror()`.

```c
if (fork() == 0) {
    execvp(args[0], args);
    perror("execvp");
    _exit(127);
}
wait(NULL);
```

#pointsextra[Agregá una tubería entre dos comandos usando `pipe()`, `dup2()` y dos procesos hijo. Probá ejecutar `ps aux | grep bash`.]

#pagebreak()
= Carreras y sincronización entre hilos (7/10)

#track("7/10")[
  *Descripción:* observar una condición de carrera y corregirla con un mutex. Es una práctica directamente útil para programación concurrente.
]

1. Crear diez hilos que incrementen contador global un millón de veces cada uno.
2. Ejecutar varias veces y comparar resultado con valor esperado.
3. Explicar por qué `contador++` no es operación indivisible.
4. Proteger incremento con `pthread_mutex_lock()` y `pthread_mutex_unlock()`.
5. Medir tiempo con y sin mutex usando `time`.
6. Confirmar cantidad de hilos con `ps -T`.

#extra[Compará mutex con operaciones atómicas usando `stdatomic.h`. Investigá por qué solución correcta puede ser más lenta y cuándo conviene cada alternativa.]

#pagebreak()
= Cambios de contexto y rendimiento (8/10)

#track("8/10")[
  *Descripción:* medir qué costo tiene alternar entre procesos e hilos. Conecta modelo teórico del planificador con datos observables.
]

1. Crear programa que haga trabajo de CPU durante varios segundos.
2. Medir cambios de contexto voluntarios y no voluntarios antes y después usando `/proc/PID/status`.
3. Comparar proceso que usa `sleep()` con otro que ocupa CPU en un loop.
4. Ejecutar dos copias del programa y observar efecto sobre cambios de contexto y tiempo de ejecución.
5. Repetir medición con dos hilos y explicar qué resultados esperás encontrar.
6. Registrar resultados en una tabla y distinguir hipótesis de observación.

#pointsextra[Usá `taskset` para fijar afinidad a un núcleo y repetí experimento. Investigá también `getrusage()` y diferencia entre tiempo de usuario y tiempo de sistema.]
