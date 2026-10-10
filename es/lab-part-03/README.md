# Parte III - Laboratorio: el horno que apagan cada quince segundos, el mostrador que nunca levanta el letrero, la queja que quedó en el libro de la vuelta pasada, y el catálogo que cambió de página

- Tiempo: 60 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style y es de DIAGNÓSTICO puro: cada paso le indica solo el objetivo, y la secuencia exacta de comandos vive en el campo cmd de ese paso para que usted la revele DESPUÉS de haber intentado resolverlo con sus propias manos. Los cuatro pasos arrancan con el sistema ya roto, porque el script de montaje aplica cuatro averías desde cargas codificadas en base64. Eso no es criptografía y no pretende serlo: es una venda de cortesía, para que usted no lea la respuesta en el mismo script que rompe el clúster. Las averías son idénticas para todo el mundo en todas las corridas, y la respuesta completa está en el campo cmd de cada paso. El Paso 1 le entrega una aplicación sana a la que el kubelet le está matando el contenedor cada pocos segundos, y usted tiene que llegar al evento que lo explica antes de tocar nada (Capítulo 7). El Paso 2 le entrega dos réplicas corriendo, un Service publicado y cero direcciones en el directorio, y usted tiene que entender por qué correr no es lo mismo que estar listo (Capítulo 7). El Paso 3 le entrega un Pod que dice 1/1 Running, no se queja de nada y no atiende a nadie, y la única prueba de lo que pasó quedó en la bitácora de la instancia anterior (Capítulo 8). El Paso 4 le entrega un manifiesto que el clúster rechaza porque fue escrito contra una página del catálogo que ya arrancaron, y usted tiene que averiguar cuál es la página vigente sin cambiar lo que el objeto hace (Capítulo 8). Ninguna comprobación le cree lo que usted escribió: todas vuelven a consultar el clúster en el momento de calificar, una entra al contenedor a preguntarle a la aplicación misma, otra llama al Service desde otro Pod, y todas exigen que la sonda o el objeto que estorbaba siga puesto. Borrar la sonda para que el síntoma se calle es el atajo que este laboratorio castiga en tres de los cuatro pasos.

## Prerrequisitos

- Una máquina Linux x86_64 desechable con kind, kubectl, docker (accesible sin sudo) y base64 en el PATH, y con al menos 4 GB de RAM libres. Confirme cada herramienta con su propio --version antes de empezar, no le crea a esta prosa. Verificado el 2026-10-09 con kind v0.33.0, kubectl v1.37.0 y Docker 29.9.0.
- AISLAMIENTO, y esto no es opcional. El laboratorio crea su propio clúster kind de un nodo llamado ckad-p03 y escribe su kubeconfig en un archivo PRIVADO, ~/ckad-lab/p03/kubeconfig, desde el primer comando. Todos los comandos kubectl de este laboratorio llevan --kubeconfig apuntando a ese archivo, y usted debe hacer lo mismo. Nunca dependa del contexto actual de su ~/.kube/config: si usted tiene otro clúster abierto, un kubectl delete sin --kubeconfig se lo lleva a él y no a este. El laboratorio no toca ningún otro clúster, contexto ni contenedor de su máquina.
- IMÁGENES FIJADAS POR DIGEST, verificadas el 2026-10-09. El nodo del clúster: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, fijada a propósito: kind v0.33.0 trae por defecto otra imagen de nodo, y el laboratorio la pasa con --image para no depender de la versión de kind que usted tenga. Las aplicaciones de los cuatro pasos: busybox@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 (BusyBox v1.37.0), que trae el servidor httpd con el que atienden. El Pod cliente mandadero, que es el teléfono desde el que se llama a los Services: curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17. Una etiqueta es mutable y un digest no: los capítulos le enseñan a buscar la versión vigente, el laboratorio la fija para que el ejercicio sea reproducible.
- Salida a internet durante el montaje, para bajar las tres imágenes fijadas. La calificación en sí no necesita internet, solo el clúster vivo: las comprobaciones consultan el API server y llaman a los Services desde adentro del propio clúster.
- El montaje tarda cerca de un minuto y medio y deja el clúster YA ROTO, a propósito. Antes de aplicar las averías mide tres cosas y se detiene con un error con nombre si alguna falla: que el API server ya no sirva batch/v1beta1, que el kubelet reinicie un contenedor cuando falla la sonda de vida, y que un Pod no listo quede fuera del directorio del Service. Si usted quiere volver a empezar un paso desde cero, corra el teardown completo y vuelva a correr el montaje: las averías se aplican en el montaje, no paso por paso. El teardown borra el clúster ckad-p03 y el directorio ~/ckad-lab/p03, nada más.
- Haber leído los Capítulos 7 y 8. Este laboratorio no vuelve a explicar qué hace cada sonda, por qué un Pod listo es distinto de un Pod corriendo, cómo se lee la bitácora de la instancia anterior de un contenedor, ni qué significa que una versión de API deje de servirse; le hace operar las cuatro cosas contra un clúster real que ya está enfermo.
- Una advertencia sobre el Paso 3, y léala antes de empezar: la evidencia de ese paso vive en la bitácora del contenedor anterior, y esa bitácora se va con el Pod. Si usted arregla primero y pregunta después, el Deployment reemplaza el Pod, la queja desaparece y le va a tocar correr el teardown y el montaje otra vez para recuperarla. Lea antes de recetar.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 7: El horno que el jefe manda a apagar cada quince segundos (10 pts)

Lo que pasa es que en la panadería del barrio contrataron un jefe nuevo y el negocio se dañó el mismo día. El horno está bueno, el pan sale, el mostrador atiende. Pero el jefe tiene una costumbre: cada pocos segundos llama a la extensión del horno para confirmar que sigue vivo, y como nadie le contesta, manda a apagarlo y a prenderlo otra vez. El horno lleva toda la mañana prendiéndose y apagándose y nadie ha comido pan.

El horno no está dañado. Lo que está mal marcado es el número de la extensión. Eso es una `livenessProbe` mal apuntada, y el Capítulo 7 fue claro en lo que significa: la sonda de vida no pregunta si la aplicación está lista, pregunta si sigue viva, y cuando decide que no lo está, el kubelet no avisa ni negocia, mata el contenedor y lo vuelve a arrancar.

Empiece por el termómetro, que es `kubectl get pods`, y mírele la columna RESTARTS: si ese número sube solo mientras usted mira, ya sabe que alguien está matando el contenedor a propósito. Después vaya a la historia clínica, que es `kubectl describe pod`, y baje hasta los eventos. Ahí el kubelet deja escrito, con nombre propio, a qué dirección y a qué puerto llamó, y qué le contestaron. Compare ese puerto con el que el contenedor declara y ya tiene el diagnóstico completo.

Y ahora la tentación, que en este paso toma dos segundos: borre la `livenessProbe` y los reinicios se acaban. Se acaban del todo, la fila queda 1/1 Running, se ve perfecto. Y usted acabó de quitarle el pulso al negocio para que dejara de sonar la alarma. La comprobación exige que la sonda siga puesta, que siga siendo un chequeo HTTP y que apunte al puerto que la aplicación atiende, y además entra al Pod a confirmarlo con sus propias manos.

ENTREGABLE: el Deployment `horno` en 1/1 con su sonda de vida todavía puesta y ya sin reiniciarse, y el archivo `~/ckad-lab/p03/01-respuesta.txt`, de 3 líneas:

```text
PUERTO_SONDA=<el puerto al que la sonda de vida estaba llamando>
PUERTO_REAL=<el puerto que el contenedor declara y atiende>
RAZON_EVENTO=<la razón que Kubernetes escribió en el evento de advertencia, tal cual, una sola palabra>
```

<details>
<summary>Qué debería ver</summary>

Antes de arreglar nada, kubectl get pods muestra un solo Pod con la columna RESTARTS subiendo cada pocos segundos: al comienzo aparece 1/1 Running con 1 o 2 reinicios, y al cabo de dos o tres minutos aparece 0/1 CrashLoopBackOff con cinco o seis, porque el kubelet ya se cansó de reintentar tan seguido. Los dos estados son la misma avería en dos momentos distintos. En los eventos hay una línea Warning con razón Unhealthy y el mensaje 'Liveness probe failed: Get "http://<IP-del-Pod>:8081/": dial tcp <IP-del-Pod>:8081: connect: connection refused', seguida de una línea Normal con razón Killing que dice que el contenedor falló la sonda de vida y va a ser reiniciado. El manifiesto declara un solo puerto de contenedor, llamado http, en el 8080. Después del arreglo el Pod queda 1/1 Running y el contador de reinicios se queda quieto: si usted mira, espera cuarenta y cinco segundos y vuelve a mirar, el número es el mismo.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 7: El mostrador que atiende pero nunca levanta el letrero de ABIERTO (10 pts)

Lo que pasa es que en la tienda de la esquina hay dos empleados detrás del mostrador, los dos llegaron, los dos están de pie, y llevan toda la mañana sin recibir un solo pedido a domicilio. El dueño jura que la central de domicilios lo tiene bloqueado. La central jura que la tienda aparece cerrada.

Los dos tienen razón, y esa es la lección del Capítulo 7. Una aplicación puede estar corriendo perfectamente y aun así no estar LISTA, y en Kubernetes eso no es una opinión, es un interruptor: mientras la `readinessProbe` no pase, el Pod no entra al directorio del Service, y si no está en el directorio, no le llega ni un solo cliente. El contenedor no se muere, no se reinicia, no se queja. Simplemente nadie lo llama.

Mire la columna READY de `kubectl get pods`: dos Pods en `0/1 Running`, con cero reinicios. Eso ya le dice que esto no es lo mismo que el Paso 1: aquí nadie está matando nada. Después mire el directorio, que es el EndpointSlice del Service, y fíjese bien, porque aquí está la parte que la gente se salta: el directorio NO está vacío. Tiene las dos direcciones anotadas, cada una con una condición que dice si esa dirección está lista o no. Un directorio vacío sería un problema de selector; un directorio con direcciones no listas es un problema de disponibilidad. Ya sabe para dónde ir.

Lea entonces qué le está preguntando la sonda a la aplicación, y hágale usted la misma pregunta a mano desde el Pod `mandadero`. Va a ver que la aplicación contesta perfectamente bien, y que lo que no existe es lo que le están preguntando. El letrero de ABIERTO no se levanta porque el jefe pidió que lo levantaran solo cuando alguien conteste en una ventanilla que nunca se construyó.

Y la tentación de siempre: borre la `readinessProbe` y las dos direcciones entran al directorio de una vez, porque un Pod sin sonda de disponibilidad se da por listo apenas arranca. Los domicilios empiezan a llegar. Y usted acabó de mandar clientes a un mostrador sin verificar nunca más si hay alguien atendiendo. La comprobación exige que la sonda siga puesta y siga siendo HTTP contra el mismo puerto.

ENTREGABLE: el Deployment `mostrador` en 2/2, las dos direcciones listas en el EndpointSlice, un curl desde el Pod `mandadero` que devuelva 200 contra `http://domicilios.la-tienda.svc.cluster.local/` con la sonda todavía puesta, y el archivo `~/ckad-lab/p03/02-respuesta.txt`, de 3 líneas:

```text
RUTA_SONDA=<la ruta HTTP que la sonda estaba pidiendo y que la aplicación no sirve>
CODIGO_HTTP=<el código de estado con el que la aplicación contestaba esa ruta>
TIPO_DE_SONDA=<el nombre del campo de la sonda culpable, tal cual se escribe en el manifiesto>
```

<details>
<summary>Qué debería ver</summary>

Antes de arreglar nada, kubectl get pods muestra los dos Pods en 0/1 Running, sin un solo reinicio: nadie los está matando, simplemente nunca llegan a estar listos. El Deployment muestra READY 0/2. El EndpointSlice del Service domicilios trae las dos direcciones IP anotadas, pero las dos con la condición ready en false, y por eso una llamada al nombre del Service se cae con código 000 y curl sale con estado 7, que es 'no pude conectar'. Aquí hay un detalle que vale el paso entero: el directorio NO está vacío. Un directorio vacío significaría que el selector no encuentra a nadie; un directorio lleno de direcciones no listas significa que el selector está bien y el problema es la disponibilidad. En los eventos aparece la razón Unhealthy con el mensaje 'Readiness probe failed: HTTP probe failed with statuscode: 404'. Un curl a mano contra la ruta que pide la sonda devuelve 404 y contra la raíz devuelve 200. Después del arreglo el Deployment queda 2/2 y la llamada al nombre del Service devuelve 200. Justo al terminar el rollout, el EndpointSlice puede listar todavía las dos direcciones viejas en false mientras sus Pods terminan, junto a las dos nuevas en true; unos segundos después quedan solo las dos nuevas.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 8: La queja que solo quedó escrita en el libro de la vuelta pasada (10 pts)

Lo que pasa es que este es el caso más incómodo de todos, porque el sistema no le está avisando nada. El Pod dice `1/1 Running`. La sonda no falla, porque nadie le puso sonda. El Deployment está completo. El tablero está en verde. Y el catálogo no abre.

El Capítulo 8 lo llamó el cliente que no dice qué le pasó, y le dejó el orden para sacarle la verdad. Lo primero es aceptar que en la tabla hay UNA sola pista, y es la columna RESTARTS: si dice 1, esa aplicación arrancó, se murió y volvió a arrancar. Algo pasó, y pasó una vez.

Lo segundo es abrir el libro de quejas de hoy, que es `kubectl logs`. Y aquí viene la sorpresa: está en blanco. Ni una línea. Eso no significa que no haya pasado nada, significa que la instancia que está corriendo AHORA no tiene nada que decir. La queja la escribió la instancia anterior, la que se murió, y esa bitácora todavía existe pero no se lee con el mismo comando: se lee con `--previous`. Esa es la herramienta que este paso le está cobrando.

Y ahora la advertencia más importante del laboratorio entero, y va en serio: esa bitácora se va con el Pod. En cuanto usted arregle el Deployment y el rollout reemplace el Pod, la queja desaparece para siempre y no hay comando que la traiga de vuelta. Lea primero, anote, y después recete. Si ya la perdió, corra el teardown y el montaje otra vez; no pasa nada, son noventa segundos.

Cuando lea el mensaje va a entender por qué el sistema nunca le avisó: alguien pidió un dato que no existe y además marcó ese dato como que no importaba si faltaba. Kubernetes le hizo caso al pie de la letra: no bloqueó el arranque, dejó la variable vacía y siguió adelante. Ese campito es el que convirtió un error de configuración, que se habría visto de una en el estado del Pod, en una falla silenciosa que solo se ve en el libro de la vuelta pasada.

Arréglelo leyendo el dato de donde toca. El precio de la página del catálogo se lee del inventario, no se aprende de memoria: si usted borra el `valueFrom` y escribe el valor a mano, el catálogo abre, el número sale bien, y usted no arregló nada. La comprobación se va a dar cuenta.

ENTREGABLE: el Deployment `catalogo` en 1/1 sirviendo la página que dice el ConfigMap, con la variable todavía leída del ConfigMap, y el archivo `~/ckad-lab/p03/03-respuesta.txt`, de 3 líneas:

```text
MENSAJE_FATAL=<la línea completa que la instancia anterior dejó escrita, tal cual, sin comillas>
LLAVE_FANTASMA=<el nombre exacto de la llave que el manifiesto pedía y que el ConfigMap no tiene>
CAMPO_QUE_LO_TAPO=<el nombre del campo del manifiesto que hizo que el contenedor arrancara igual en vez de fallar de una>
```

<details>
<summary>Qué debería ver</summary>

Antes de arreglar nada, kubectl get pods muestra un solo Pod en 1/1 Running con 1 reinicio, y ese 1 es la única pista que la tabla le da: el Pod se ve sano. Una llamada al Service devuelve código 000 y curl sale con estado 7, porque adentro del contenedor no hay nada escuchando. kubectl logs contra ese Pod no imprime absolutamente nada, ni una línea. kubectl logs con --previous imprime una sola línea: `FATAL: PAGINA_CATALOGO vacia, el catalogo no abre`. El manifiesto pide la variable PAGINA_CATALOGO con un configMapKeyRef que apunta al ConfigMap el-inventario y a la llave PAGINA_VIEJA, con optional en true; el ConfigMap el-inventario existe y tiene una sola llave, PAGINA_CATALOGO, con el valor edicion-2026-08. Ese optional en true es la razón de que el Pod arrancara en vez de quedarse en CreateContainerConfigError: le dijo a Kubernetes que siguiera adelante aunque la llave no estuviera. Después del arreglo el Pod nuevo queda 1/1 Running con 0 reinicios y el curl al Service devuelve el cuerpo 'catalogo edicion-2026-08'. El primer intento puede salir con estado 7 si el Pod nuevo todavía no entró al directorio del Service; por eso el comando reintenta cada cinco segundos.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 8: El catálogo que cambió de página y nadie avisó en la bodega (10 pts)

Lo que pasa es que en la bodega tienen un conteo de inventario que corre sólito cada minuto desde hace años, y esta semana lo montaron en el clúster nuevo y no arrancó nunca. El encargado dice que "el archivo es el mismo de siempre" y tiene toda la razón: el archivo es el mismo. Lo que cambió fue el catálogo de la ferretería.

El Capítulo 8 lo dijo con esas palabras: una versión de API es una página de un catálogo, y las páginas se retiran. No se retiran de un día para otro ni a escondidas, se anuncian con años de anticipación, se marcan como obsoletas, y en una versión concreta dejan de servirse. El objeto que usted mandó no está mal escrito: está escrito contra una página que ya arrancaron del catálogo.

El montaje ya intentó aplicar ese manifiesto por usted y le guardó el rechazo textual en `~/ckad-lab/p03/inventario/apply-fallido.log`. Léalo completo, incluida la segunda línea, y desconfíe de ella: le va a sugerir que faltan CRD. Aquí no falta ningún CRD. Esa línea es el mensaje genérico que el cliente imprime cuando no encuentra el tipo de objeto, y es una pista falsa clásica.

Ahora la parte que este paso le está cobrando: no adivine cuál es la página buena, pregúntele al clúster. `kubectl api-resources` le dice, para cada tipo de objeto, qué versión sirve ESE clúster hoy, y `kubectl explain` le confirma la forma del objeto. Leer el catálogo vigente del clúster que uno tiene en frente vale mucho más que acordarse de lo que decía el catálogo el año pasado. Para la tercera línea del entregable si le toca ir a la documentación oficial: Kubernetes publica una guía de versiones de API retiradas que dice, recurso por recurso, desde qué versión dejó de servirse cada una.

Y la advertencia: aquí la tentación no es borrar una sonda, es "arreglarlo" cambiando lo que el objeto hace. Volverlo un Job suelto que corra una vez, cambiarle el horario para que no moleste, o dejarlo suspendido. Las tres cosas hacen que el error desaparezca de la pantalla y que el inventario siga sin contarse. La comprobación busca el trabajo más reciente que haya terminado bien, confirma que lo haya creado ese CronJob y le lee los registros para ver si el conteo se hizo.

ENTREGABLE: el CronJob `conteo-inventario` vivo en el namespace `el-deposito`, con el mismo nombre, el mismo horario y el mismo comando, y con al menos un Job suyo terminado correctamente; y el archivo `~/ckad-lab/p03/04-respuesta.txt`, de 3 líneas:

```text
APIVERSION_MUERTA=<la versión de API contra la que estaba escrito el manifiesto>
APIVERSION_VIVA=<la versión de API que este clúster sirve hoy para ese recurso>
VERSION_QUE_LA_RETIRO=<la versión de Kubernetes desde la cual esa versión de API dejó de servirse, escrita como vX.YY>
```

<details>
<summary>Qué debería ver</summary>

El archivo apply-fallido.log del montaje trae el rechazo textual: 'error: resource mapping not found for name: "conteo-inventario" namespace: "el-deposito" from ...: no matches for kind "CronJob" in version "batch/v1beta1"', seguido de la línea 'ensure CRDs are installed first'. Esa segunda línea es una pista falsa amable: aquí no falta ningún CRD, lo que falta es la página del catálogo. kubectl -n el-deposito get cronjobs responde 'No resources found in el-deposito namespace.', porque el objeto nunca llegó a crearse. kubectl api-resources --api-group=batch muestra dos filas, cronjobs y jobs, las dos con APIVERSION batch/v1 y ninguna con batch/v1beta1: ese es el catálogo vigente de este clúster, leído del clúster mismo y no de la memoria. Después de cambiar únicamente la línea apiVersion, el apply responde 'cronjob.batch/conteo-inventario created'. Con el horario cada minuto, en menos de sesenta segundos aparece un Job con COMPLETIONS 1/1 y STATUS Complete, y sus registros traen una línea que empieza por 'conteo terminado:' seguida de una marca de tiempo.

</details>

```bash
./04-step.sh
./04-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

## Cómo correrlo

```bash
./00-setup.sh                  # crea el clúster y deja todo listo
./01-step.sh && ./01-check.sh  # haga el paso, compruebe que quedó bien
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./99-teardown.sh               # borra el clúster y el espacio de trabajo
```

## Si algo falla

- **Síntoma (step 1):** El Pod aparece 0/1 CrashLoopBackOff y no 1/1 Running; parece otra avería distinta
  **Qué hacer:** Es la misma avería más tarde. El kubelet reinicia el contenedor cada vez que la sonda de vida falla, y cuando lleva varios reinicios seguidos deja de reintentar de inmediato y empieza a esperar cada vez más entre intentos: eso es lo que se muestra como CrashLoopBackOff. La pista buena no es la palabra del STATUS sino el número de la columna RESTARTS y el evento con razón Unhealthy, que siguen ahí en los dos casos. Arregle el puerto y el Pod sale del compás de espera solo.

- **Síntoma (step 1):** Ya corregí el puerto y la comprobación se queda callada casi un minuto antes de contestar
  **Qué hacer:** Es a propósito. Un contador de reinicios quieto solo se puede probar mirándolo dos veces con tiempo en medio, así que la comprobación lo lee, espera cuarenta y cinco segundos y lo vuelve a leer. Espere a que el rollout termine antes de calificar, con kubectl rollout status deployment/horno, porque si usted califica en mitad de la actualización el Pod que la comprobación escoge puede ser el viejo.

- **Síntoma (step 2):** kubectl get endpoints me muestra la columna ENDPOINTS vacía, pero kubectl get endpointslices me muestra dos direcciones. ¿Cuál de las dos me está mintiendo?
  **Qué hacer:** Ninguna. Son dos vistas del mismo hecho: el EndpointSlice lista TODAS las direcciones que el selector encontró y le pone a cada una una condición ready que dice si está lista o no; la vista vieja de Endpoints solo muestra las que están listas. Por eso una se ve vacía y la otra no. La columna que le sirve para diagnosticar es la condición ready del EndpointSlice, que es la que distingue 'no encontré a nadie' de 'los encontré y ninguno está listo'.

- **Síntoma (step 2):** Cambié la sonda y el curl desde mandadero sigue fallando durante unos segundos
  **Qué hacer:** Deje pasar el rollout completo y unos segundos más. El Deployment reemplaza los Pods de a uno, cada Pod nuevo tiene que pasar su sonda antes de entrar al directorio, y el directorio tarda un instante en propagarse. Use kubectl rollout status deployment/mostrador para esperar en vez de repetir el curl, y confirme con la condición ready del EndpointSlice antes de volver a llamar. La comprobación ya reintenta el curl varias veces por esa misma razón.

- **Síntoma (step 3):** kubectl logs --previous me responde 'previous terminated container not found'
  **Qué hacer:** Eso significa que ese Pod no tiene instancia anterior, y casi siempre significa que usted está preguntándole a un Pod nuevo: si ya cambió el Deployment, el Pod que ve ahora nació después del arreglo y nunca se murió. La bitácora vieja se fue con el Pod viejo y no se recupera. Corra el teardown y el montaje otra vez y esta vez lea antes de tocar. Confirme siempre que le está preguntando al Pod correcto mirando la columna RESTARTS: si dice 0, no hay nada anterior que leer.

- **Síntoma (step 3):** La comprobación me rechaza la línea MENSAJE_FATAL aunque yo copié el texto
  **Qué hacer:** La línea se compara completa y exacta, así que revise tres cosas: que no le haya quedado un espacio de más al final, que no haya puesto comillas alrededor del mensaje, y que haya copiado la línea entera incluyendo la palabra FATAL y los dos puntos. El formato es MENSAJE_FATAL= seguido inmediatamente del texto tal como lo imprimió el contenedor, sin nada más. Copie y pegue desde la salida de kubectl en vez de transcribir a mano.

- **Síntoma (step 4):** Apliqué el manifiesto corregido y kubectl -n el-deposito get jobs no muestra nada
  **Qué hacer:** Un CronJob no corre en el momento en que usted lo crea, corre cuando el horario lo dispara. Con el horario cada minuto le puede tocar esperar hasta sesenta segundos para ver el primer Job, y unos segundos más para que termine. Mire la columna LAST SCHEDULE de kubectl get cronjob: mientras esté vacía, todavía no ha disparado. Si pasados dos minutos sigue sin disparar, confirme que la columna SUSPEND diga False.

- **Síntoma (step 4):** El error dice 'ensure CRDs are installed first' y me fui a buscar qué CRD instalar
  **Qué hacer:** Esa línea es genérica: kubectl la imprime siempre que no logra resolver un kind contra ninguna versión servida, sin importar la causa, y muchas veces la causa no es un CRD faltante sino una versión de API retirada. La forma de decidir cuál de las dos es, en diez segundos, es kubectl api-resources: si el kind aparece ahí con otra APIVERSION, el problema es la versión y no un CRD; si no aparece por ningún lado, ahí si valdría preguntarse por una extensión que falta.

## Para ir más lejos

- Vuelva al Paso 1 y rompa el horno al revés: deje la sonda de vida apuntando bien y póngale una startupProbe con un presupuesto muy corto a una aplicación que tarda en abrir, por ejemplo un contenedor que duerma cuarenta segundos antes de levantar el httpd. Prediga por escrito, antes de aplicar nada, si el evento que va a ver dirá Liveness o Startup, y después compruébelo. Es la diferencia entre una aplicación enferma y una aplicación que simplemente todavía no ha terminado de abrir.
- En el Paso 2, en vez de corregir la ruta de la sonda, hágalo por el otro camino válido: deje la sonda pidiendo /abierto y haga que la aplicación sirva esa ruta. Los dos arreglos respetan el control y los dos pasan la comprobación. Escriba tres líneas sobre cuál preferiría en producción y por qué, y en particular sobre qué pasa el día que alguien cambie la aplicación sin saber que hay una sonda mirando esa ruta.
- En el Paso 3, ponga el laboratorio en el estado en que debió estar desde el principio: agréguele al Deployment catalogo una readinessProbe HTTP contra el 8080. Después vuelva a romperlo apuntando la variable a una llave que no existe y observe la diferencia. Con sonda, el Pod nunca llega a listo y el Service nunca lo publica; sin sonda, el Pod se ve verde y el cliente se estrella. Ese contraste es todo el Capítulo 7 en un solo experimento.
- En el Paso 4, haga el ejercicio inverso y más útil en la vida real: busque en la guía oficial de versiones retiradas otro recurso que también haya cambiado de página, escriba un manifiesto contra la versión vieja, aplíquelo en este mismo clúster y compare el rechazo con el que ya conoce. Después corríjalo. Dos casos son suficientes para que el patrón deje de sorprenderlo.

## Referencias

- Kubernetes documentation, Configure Liveness, Readiness and Startup Probes. Documents the probe fields Steps 1 and 2 diagnose, including httpGet, initialDelaySeconds, periodSeconds and failureThreshold. https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- Kubernetes documentation, Pod Lifecycle. Documents container restarts, the restart back-off behind CrashLoopBackOff, and what each probe does when it fails. https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- Kubernetes documentation, Debug Running Pods. The reference for kubectl logs and the --previous flag Step 3 is built on. https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/
- Kubernetes documentation, Debug Pods. The describe-plus-events procedure Steps 1 and 2 follow. https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- Kubernetes documentation, Debug Services. The ordered service-path procedure Step 2 follows: Pods ready first, then endpoints, then the call. https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- Kubernetes documentation, EndpointSlices. Documents the ready condition per address that Step 2 reads to tell a selector problem apart from a readiness problem. https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Kubernetes documentation, ConfigMaps. Documents configMapKeyRef and the optional field that turns the Step 3 configuration error into a silent runtime failure. https://kubernetes.io/docs/concepts/configuration/configmap/
- Kubernetes documentation, Deprecated API Migration Guide. States that the batch/v1beta1 API version of CronJob is no longer served as of v1.25, the fact Step 4 asks you to look up. https://kubernetes.io/docs/reference/using-api/deprecation-guide/
- Kubernetes documentation, CronJob. Documents the schedule, jobTemplate and suspend fields Step 4 must preserve. https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- kind documentation, Quick Start. Documents cluster creation and the --kubeconfig flag this lab uses for isolation. https://kind.sigs.k8s.io/docs/user/quick-start/
- kind release v0.32.0. Source of the pinned kindest/node:v1.36.1 image digest this lab runs on, verified 2026-08-21. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
