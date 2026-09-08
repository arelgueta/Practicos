#set text(lang: "es")
#set heading(numbering: "1.1")
#set page(header: align(right, text(size: 8pt)[Licenciatura en Ciencias de la Computacion#linebreak()Sistemas Operativos#linebreak()#line(length: 100%, stroke: 0.5pt)]), numbering: "1 / 1")

#let track = (score, body) => rect(fill: green.transparentize(90%), stroke: green.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *TRACK -- #score*

  #body
]

#let bonus = x => rect(fill: red.transparentize(90%), stroke: red.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *BONUS -- POR PUNTOS*

  #x
]

#let extra = x => rect(fill: orange.transparentize(90%), stroke: orange.transparentize(30%), radius: 1em, width: 100%, inset: 1em)[
  *EXTRA*

  #x
]

#align(center + horizon)[
  #text(size: 24pt, weight: "bold")[Trabajo Práctico 5 - Ejercicios extra]
  #v(1em)
  #text(size: 14pt, weight: "bold")[SISTEMAS OPERATIVOS]
]

#pagebreak()
#outline(title: "Tracks")
#pagebreak()

= Límite de instancias con un semáforo (7/10)

#track("7/10", [
  *Descripción:* limitar la cantidad de instancias concurrentes de un programa
  usando un semáforo contador de System V.
])

Implementá un programa que limite la cantidad de instancias concurrentes usando
un semáforo de System V. Interfaz sugerida:

```text
instance-limit SEM_KEY MAX_INSTANCES -- COMMAND [ARGS...]
```

Investigá la inicialización, la reserva y liberación de cupos, el comportamiento
cuando se alcanza el límite y la limpieza del semáforo.

#bonus[
  Extendé el programa para que pueda detectar una instancia abandonada y
  recuperar su cupo sin afectar otros procesos. Documentá qué garantías ofrece
  `SEM_UNDO` y cómo se comporta el programa frente a una terminación normal,
  `SIGTERM` y `SIGKILL`.
]

= Aproximación de pi y rendimiento

#track("PI", [
  *Descripción:* aproximar pi sumando términos de una expansión y medir el
  costo de aumentar la cantidad de términos.
])

Implementá un programa secuencial que reciba `N` y calcule:

```text
pi_N = 4 * sum((-1)^k / (2*k + 1), k = 0 .. N-1)
```

El error de esta aproximación cumple:

```text
|pi - pi_N| < 4 / (2*N + 1)
```

Mostrá la aproximación, el error y el tiempo de ejecución. Probá distintos
valores de `N` y compará los resultados.

#bonus[
  Implementá una segunda versión del programa usando OpenMP. Debe calcular
  la misma aproximación de pi, aceptar los mismos parámetros y producir
  resultados comparables con la versión secuencial. Compará la ejecución
  secuencial con distintas cantidades de hilos e informá el speedup. Se sugiere
  usar C o C++.
]

= Transferencia por pipes y SSH

#track("SSH", [
  *Descripción:* transferir y extraer un directorio remoto usando un pipe, sin
  crear un archivo intermedio.
])

Investigá brevemente qué resuelven `scp` y `rsync`, y compará esas herramientas
con una transferencia basada en un flujo de datos.

Después, escribí una única línea de comandos que:

- empaquete un directorio local y envíe el resultado por la salida estándar;
- use `ssh` para transportar ese flujo;
- extraiga el flujo en un directorio de la máquina remota.

La solución debe usar pipes, `ssh` y `tar`. No uses `scp` ni `rsync` para
resolverla, y no generes un archivo intermedio. Probá la línea con una máquina
remota y verificá que la estructura y el contenido lleguen correctamente.

= Cliente-servidor: solicitud y respuesta

#track("IPC", [
  *Descripción:* implementar una comunicación básica entre un proceso cliente
  y un proceso servidor.
])

Implementá dos procesos:

- el servidor espera una solicitud, la procesa y envía una respuesta;
- el cliente envía la solicitud y muestra la respuesta recibida.

Elegí una operación sencilla, por ejemplo, solicitar al servidor que tire un
dado o enviarle una cuenta aritmética para que devuelva el resultado. Definí
un protocolo simple y asegurá al menos un intercambio completo de solicitud y
respuesta mediante un mecanismo de comunicación entre procesos.

#bonus[
  Convertí la solución en un juego mínimo con dos procesos. El cliente debe
  mostrar un rectángulo grande usando secuencias de escape ANSI y un personaje
  dentro del área. Configurá la entrada del terminal sin modo canónico ni eco
  para leer las teclas `W`, `A`, `S` y `D`
  inmediatamente, y restaurá la configuración al salir.

  Cada tecla debe enviarse al servidor. El servidor debe validar y aplicar el
  movimiento, devolver el estado actualizado, incluyendo la posición del
  personaje, y mantener la autoridad exclusiva sobre el estado. El cliente debe
  renderizar en tiempo real únicamente el estado recibido.
]

= Heartbeat y watchdog

#track("WATCHDOG", [
  *Descripción:* detectar la ausencia de un proceso mediante mensajes
  periódicos de heartbeat.
])

Implementá dos procesos:

- un proceso de trabajo que envíe periódicamente un mensaje de heartbeat;
- un watchdog que reciba esos mensajes y controle el tiempo transcurrido desde
  el último heartbeat.

Si el watchdog no recibe un heartbeat dentro de un timeout configurable, debe
informar que el proceso dejó de responder. Usá un mecanismo de comunicación
entre procesos, definí el formato de los mensajes y asegurá el cierre correcto
de los descriptores.

Probá tanto el funcionamiento normal como la ausencia o terminación del
proceso de trabajo.
