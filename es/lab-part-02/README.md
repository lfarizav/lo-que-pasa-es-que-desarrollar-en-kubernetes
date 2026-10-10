# Parte II - Laboratorio: cambiar el turno sin bajar de cuatro meseros, devolverse a la carta de antier y no a la de ayer, servirle el plato nuevo a uno de cada cinco clientes, y abrir la franquicia con el manual de armado en la versión que le prometieron

- Tiempo: 55 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo y el estado final que se califica, y la secuencia exacta de comandos vive en el campo cmd de ese paso para que usted la revele después de haber intentado primero por su cuenta. El Paso 1 le pone una restricción de negocio escrita con números (en la hora pico nunca pueden quedar menos de cuatro puestos atendiendo, y en la cocina no caben más de cinco cocineros al tiempo) y le pide afinar maxSurge y maxUnavailable para que el rolling update la respete; la calificación no compara textos, sino que convierte lo que usted escribió a número de Pods y exige que ese número cumpla la restricción, así que la forma entera y la forma en porcentaje valen las dos si cumplen (Capítulo 4). El Paso 2 le hace construir tres revisiones y después devolverse con kubectl rollout undo a una revisión concreta, no a la anterior, y le califica el estado final de la anotación de revisión, que es donde la intuición falla: el número no baja, sube, y la revisión a la que usted se devolvió desaparece del historial porque Kubernetes le renumera el ReplicaSet (Capítulo 4). El Paso 3 le hace montar un canario, dos Deployments distintos compartiendo un solo Service, en una proporción declarada de ocho a dos, y la comprobación no le cree a las réplicas declaradas: cuenta los endpoints vivos del Service uno por uno, los cruza contra la etiqueta de versión del Pod dueño de cada endpoint, y después levanta su propia sonda que dispara cien peticiones para confirmar que el Service reparte entre las dos versiones (Capítulo 5). El Paso 4 le hace desplegar una aplicación con Helm fijando la versión del chart, y la comprobación revisa las tres capas: que exista el registro de release de Helm con esa versión exacta, que los valores que usted pasó vivan en el release y no solo en el clúster, y que la aplicación corriendo reporte por su propia boca la versión y el mensaje que usted configuró (Capítulo 6). Ninguna comprobación lee su historial de comandos: todas vuelven a consultar el clúster, y dos de ellas crean sondas nuevas y las borran para confirmar que el sustrato hace lo que el laboratorio asume.

## Prerrequisitos

- Una máquina Linux con kind, kubectl, helm y Docker en el PATH, y con al menos 4 GB de RAM libres. Este laboratorio levanta su PROPIO clúster kind de tres nodos llamado ckad-p02 y escribe su kubeconfig en un archivo privado, ~/ckad-lab/p02/kubeconfig, que no es el suyo de siempre. Nunca toca ~/.kube/config, ni su contexto actual, ni ningún otro clúster que usted ya tenga corriendo. Por eso TODOS los comandos del laboratorio llevan --kubeconfig; si se le olvida el flag una sola vez, kubectl le apunta a otro clúster y usted no se entera.
- Helm también queda aislado. El Paso 4 exporta HELM_CONFIG_HOME, HELM_CACHE_HOME, HELM_DATA_HOME, HELM_REPOSITORY_CONFIG y HELM_REPOSITORY_CACHE hacia ~/ckad-lab/p02/helm, de modo que el repositorio de charts que usted agrega aquí no se mete en la configuración de helm que usted ya tenga en su máquina. Si abre una terminal nueva a mitad del Paso 4, vuelva a exportar esas cinco variables antes de seguir.
- Tres nodos, no uno. El clúster se crea con un archivo de configuración de kind que declara un control-plane y dos workers, porque el Paso 1 necesita que las cuatro réplicas se repartan para que el rolling update signifique algo, y el Paso 3 monta diez Pods que tienen que caber en algún lado.
- Acceso a internet en el momento de montar el laboratorio y durante el Paso 4: kind descarga la imagen de nodo, los Pods descargan las tres imágenes de nginx fijadas por digest, y helm descarga el chart desde su repositorio público. La calificación de los Pasos 1, 2 y 3 no necesita internet; la del Paso 4 tampoco, porque para entonces el chart ya está instalado, pero si necesita que el binario helm siga en el PATH.
- VERSIONES FIJADAS, verificadas el 2026-10-09 en esta misma máquina. kind v0.33.0, kubectl v1.37.0 y helm v4.3.0 (el laboratorio solo usa subcomandos de helm que existen desde la serie 3.13, así que una helm 3 reciente también sirve). Imagen de nodo kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, declarada explícitamente en el archivo de configuración para que no dependa de la versión de kind que usted tenga. Confirme lo que quedó instalado con kind version, kubectl version --client y helm version, nunca de memoria, y confirme la versión real de sus nodos con kubectl get nodes.
- TRES imágenes de contenedor fijadas por digest, verificadas el 2026-10-09 contra Docker Hub desde esta máquina. La vieja, nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10; la de en medio, nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236; y la nueva, nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. Son tres porque el Paso 2 necesita construir tres revisiones para poder devolverse a la de en medio, que es donde vive la lección. Un tag es mutable, un digest no, y por eso las comprobaciones comparan la cadena completa con digest y no el tag suelto. Además las tres se delatan solas por la cabecera Server de nginx, y el Paso 3 usa esa cabecera como prueba de que el Service reparte el tráfico.
- UN chart de Helm fijado por versión, verificado el 2026-10-09: podinfo 6.13.0, desde el repositorio público https://stefanprodan.github.io/podinfo. Se escogió una versión que NO es la última a propósito: el día de la verificación la última era la 6.15.0, así que un helm install sin --version le trae otra cosa y el paso falla. Esa es justamente la lección del Capítulo 6.
- Haber leído los Capítulos 4, 5 y 6. Este laboratorio no vuelve a explicar que es un ReplicaSet, que diferencia hay entre azul-verde y canario, ni que es un chart; le hace operar las cuatro cosas contra un clúster real y le califica el estado final.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 4: Cambiar el turno con la restricción del dueño escrita en números (10 pts)

El Capítulo 4 dejó el negocio abierto y la lección puesta: usted no cierra para cambiar el turno. Lo que pasa es que en el examen nunca le van a decir "ponga maxSurge en 1". Le van a decir una restricción de negocio, con números, y usted tiene que traducirla. Esa traducción es el paso.

La restricción del dueño, tal cual: en la hora pico NUNCA pueden quedar menos de CUATRO puestos atendiendo, y en la cocina NO caben más de CINCO cocineros al tiempo. El Deployment tiene cuatro réplicas. Siéntese cinco segundos con eso antes de escribir nada. Si nunca pueden quedar menos de cuatro atendiendo y usted tiene cuatro, entonces cuántos puede tener caídos al tiempo. Y si en total no caben más de cinco, cuántos de más puede crear mientras reemplaza.

El error que se comete por afán es dejar la estrategia como viene de fábrica. Kubernetes trae 25% y 25%, y sobre cuatro réplicas ese 25% de no disponibles significa que se le permite dejar UN puesto vacío. El rollout va a terminar bien, todo se va a ver verde, y usted acaba de violar la restricción que le escribieron. Un rollout que termina no es un rollout que cumple.

Y hay una cosa que vale la pena mirar mientras corre, porque es la única prueba visible de que la restricción se está respetando: la narración de rollout status. Con no-disponibles en cero, el controlador crea primero el Pod nuevo, espera a que quede Ready, y SOLO entonces mata uno viejo. Por eso usted va a leer "1 out of 4", "2 out of 4", "3 out of 4" y hasta el final "1 old replicas are pending termination". Si usted hubiera aflojado la restricción, esa narración seria otra.

ENTREGABLE: el Deployment turno-de-almuerzo corriendo en el namespace el-restaurante con la imagen nueva, sus cuatro réplicas listas, y una estrategia que cumpla la restricción; y el archivo `~/ckad-lab/p02/01-respuesta.txt`, de 3 líneas:

```text
MAX_SURGE=<lo que dice .spec.strategy.rollingUpdate.maxSurge del Deployment ahora, tal cual quedó guardado>
MAX_UNAVAILABLE=<lo que dice .spec.strategy.rollingUpdate.maxUnavailable del Deployment ahora, tal cual quedó guardado>
REPLICAS_LISTAS=<lo que dice .status.readyReplicas ahora>
```

<details>
<summary>Qué debería ver</summary>

Al crear el Deployment, la consulta de estrategia responde tipo=RollingUpdate, surge=1 y nodisp=0, que es lo que usted escribió guardado tal cual en el objeto. Cuando cambia la imagen, rollout status va narrando el reemplazo de una manera muy particular que hay que quedarse leyendo: dice 1 out of 4 new replicas have been updated, después 2 out of 4, después 3 out of 4, y solo al final dice 1 old replicas are pending termination. Nunca dice que haya menos de cuatro disponibles, porque con maxUnavailable en 0 el controlador crea primero el Pod nuevo, espera a que este listo, y solo entonces mata uno viejo. Al terminar, listas, actualizadas y disponibles dicen 4, 4 y 4, la imagen viva termina en el digest 56168782, y el listado de ReplicaSets muestra dos objetos: el de la imagen de en medio con revisión 1 y DESEADAS en 0, y el de la imagen nueva con revisión 2 y DESEADAS en 4.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 4: Devolverse a la carta de antier, y descubrir que el número de revisión sube en vez de bajar (10 pts)

El Capítulo 4 dijo que devolverse es parte del oficio. Lo que pasa es que casi todo el mundo practica el rollback fácil, el de un solo paso para atrás, y el día que la carta mala lleva dos cambios encima se quedan mirando la pantalla. Este paso es el difícil a propósito.

Usted va a construir tres revisiones: la carta vieja, la carta de en medio, la carta nueva. Y la queja de los clientes no es contra la nueva sino contra las dos últimas: toca devolverse a la de EN MEDIO, no a la anterior. Eso ya no es rollout undo a secas, eso es rollout undo apuntando a una revisión concreta.

Esta es la parte que le va a doler la primera vez, así que se la digo antes: cuando usted se devuelve a la revisión 2, la anotación de revisión del Deployment NO queda en 2. Queda en 4. El número de revisión no es una posición en una lista a la que usted regresa, es un contador que solo sube, y devolverse también cuenta como un cambio. Y más raro todavía: cuando vuelva a mirar rollout history, la fila de la revisión 2 ya no está. Va a ver 1, 3 y 4.

No se asuste y sobre todo no vuelva a hacer nada encima. No se perdió nada. Kubernetes no copió ni recreó el ReplicaSet viejo: agarró el mismo, el que ya tenía la imagen de en medio guardada, y le cambió la anotación de 2 a 4, porque es el mismo conjunto de Pods. La revisión 2 no se borró, se renombró. Si usted mira los tres ReplicaSets con sus números al lado, la historia completa está ahí y cuadra.

Y una nota de honestidad, porque este laboratorio califica estado final y no camino: si en vez de rollout undo --to-revision=2 usted simplemente vuelve a hacer set image a la imagen de en medio, llega al mismo sitio, revisión 4 incluida. Los dos caminos pasan. Se verificaron los dos.

ENTREGABLE: el Deployment carta-de-la-semana corriendo en el-restaurante con la imagen de en medio y sus tres réplicas listas, y el archivo `~/ckad-lab/p02/02-respuesta.txt`, de 3 líneas:

```text
REVISION_FINAL=<lo que dice la anotación `deployment.kubernetes.io/revision` del Deployment ahora>
IMAGEN_VIVA=<la cadena completa de la imagen que corre ahora, con tag y digest>
REVISIONES_VIVAS=<los números de revisión de los ReplicaSets que existen ahora, de menor a mayor, separados por comas y sin espacios, por ejemplo 1,3,4>
```

<details>
<summary>Qué debería ver</summary>

Antes del undo, rollout history lista TRES filas limpias: 1, 2 y 3. Después del undo a la revisión 2, la anotación del Deployment NO dice 2: dice 4. La imagen viva vuelve a ser la de en medio, la que termina en el digest a8b39bd9, y listas dice 3. Y aquí está lo que hay que ver con los propios ojos porque no se olvida más: rollout history DESPUÉS del undo lista 1, 3 y 4. La revisión 2 desapareció del historial. No se borró nada y no se perdió nada: Kubernetes reutilizó ese mismo ReplicaSet viejo, el que tenía la imagen de en medio, y le cambió la anotación de revisión de 2 a 4, porque es el mismo conjunto de Pods al que usted se devolvió. Por eso el listado de ReplicaSets muestra tres objetos, con revisiones 1, 3 y 4, y el único que tiene DESEADAS en 3 es el de revisión 4.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 5: El plato nuevo para uno de cada cinco clientes, con una sola caja registradora (10 pts)

El Capítulo 5 contó la diferencia entre azul-verde y canario, y este paso le hace construir el canario, que es el que más se pregunta y el que peor se entiende.

Lo que pasa es que la gente se imagina el canario como una cosa muy sofisticada, con porcentajes configurables y un panel de control. En Kubernetes puro no hay nada de eso. El canario es aritmética de Pods y una sola caja registradora. Usted monta DOS Deployments distintos, cada uno con su propia imagen, y les pone a los dos la MISMA etiqueta compartida. Después monta UN solo Service cuyo selector nombra únicamente esa etiqueta compartida y NO nombra la versión. Y ya. El Service junta los Pods de los dos Deployments en una sola bolsa de endpoints y kube-proxy reparte al azar entre todos. La proporción no la configura nadie: sale del número de réplicas de cada lado.

La orden del dueño: uno de cada cinco clientes prueba el plato nuevo, y en el salón tiene que haber diez puestos atendiendo en total. Haga la cuenta antes de escribir el YAML.

Hay una confusión que conviene aclarar de una vez: la etiqueta `version` SÍ va en los Pods, y SÍ va en el selector de cada Deployment, pero NO va en el selector del Service. Esas son tres cosas distintas que se escriben parecido. El selector del Deployment tiene que distinguir las dos versiones, porque si no cada Deployment adoptaría los Pods del otro y se pelearían por las réplicas. El selector del Service tiene que NO distinguirlas, porque ahí está todo el truco. Si usted copia el mismo selector en los dos sitios, termina con dos Services o termina en una pelea.

Y no se quede con la teoría: al final del paso levante una sonda dentro del clúster y pídale cien veces la página al Service. Las dos versiones de nginx se delatan solas en la cabecera Server, y usted va a ver con sus ojos como la misma dirección contesta unas veces 1.28 y otras 1.29. Eso es el canario funcionando, y es lo mismo que hace la comprobación cuando lo califica.

ENTREGABLE: el Service el-restaurante y los dos Deployments corriendo en el namespace la-plaza, en la proporción que pidió el dueño, y el archivo `~/ckad-lab/p02/03-respuesta.txt`, de 3 líneas:

```text
ENDPOINTS_TOTALES=<cuántos endpoints listos tiene el Service el-restaurante ahora>
ENDPOINTS_NUEVO=<cuántos de esos endpoints son Pods de la versión nueva>
PORCENTAJE_NUEVO=<que porcentaje del total representa el canario, número entero sin el símbolo de porcentaje>
```

<details>
<summary>Qué debería ver</summary>

El selector del Service sale como `{"app":"menu"}` y nada más: no nombra la versión, y esa es toda la mecánica del canario. La consulta de endpointslices lista DIEZ nombres de Pod, ocho que empiezan por sabor-de-siempre y dos que empiezan por sabor-nuevo, todos como destinos listos del mismo Service. La tabla de Pods confirma la etiqueta `version` de cada uno. Y la sonda es la parte que convence: cien peticiones al mismo nombre http://el-restaurante/ vuelven con DOS cabeceras Server distintas, nginx/1.28.3 y nginx/1.29.8, repartidas alrededor de ochenta y veinte. No van a salir 80 y 20 limpios, porque kube-proxy escoge al azar en cada conexión nueva; en la verificación de este laboratorio salieron 82 y 18 en una corrida del 2026-10-09. Lo que importa no es el número exacto sino que aparezcan las dos versiones.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 6: Abrir la franquicia con el manual de armado, en la versión que le prometieron y no en la última que salió (10 pts)

El Capítulo 6 comparó el chart con el manual de armado de una franquicia: usted no vuelve a inventarse el local, le llega el manual con todo adentro y usted solo ajusta lo del barrio. Este paso le hace abrir la sucursal.

Lo que pasa es que casi todo el mundo aprende Helm escribiendo helm install y ya, y ese comando trae lo ÚLTIMO que haya en el repositorio ese día. Funciona hoy. Mañana sale una versión nueva del chart, el mismo comando trae otra cosa, y su ambiente de producción y el de su compañero ya no son el mismo ambiente aunque los dos hayan corrido el mismo comando. Por eso este paso le pide fijar la versión del chart, y le pide fijar una que NO es la última, para que se note.

Y hay tres capas que hay que aprender a separar, porque el examen las mezcla a propósito.

La primera es el REGISTRO del release. Helm no tiene servidor ni base de datos: guarda cada release en un Secret dentro del propio namespace, llamado sh.helm.release.v1.<release>.<número>. Si ese Secret no existe, no hay release, aunque haya Pods corriendo.

La segunda son los VALORES. Los valores que usted pasa con --set no se quedan en el Deployment, se guardan en el release. Y de ahí sale el error más caro de todos.

Imagine el caso: si a usted le piden tres réplicas y las consigue con kubectl scale, el Deployment vivo va a decir 3 y el release va a seguir diciendo 1. Se ve perfecto. Y el día que alguien corra un helm upgrade rutinario, sin tocar nada relacionado, el release manda y le devuelve el número a 1 delante de todo el mundo. Lo que se escala en un release se escala por el valor del chart, no por fuera.

La tercera capa es la aplicación CORRIENDO, que es la única que no se puede fingir. Por eso al final va a levantar una sonda dentro del clúster y le va a preguntar a la aplicación quien es. Y la aplicación le va a contestar un JSON con su propia versión y con el mensaje que usted le configuro. Ahí se cierra el círculo: manual fijado, valores puestos, negocio abierto.

ENTREGABLE: el release franquicia-del-barrio instalado con Helm en el namespace la-franquicia, desde el chart fijado, con tres réplicas y con el mensaje `lo que pasa es que aqui si atienden` puestos como valores del chart, y el archivo `~/ckad-lab/p02/04-respuesta.txt`, de 3 líneas:

```text
VERSION_DEL_CHART=<la versión del chart que Helm reporta para este release, solo el número>
MENSAJE_VIVO=<el mensaje que la aplicación corriendo devuelve en su JSON, tal cual>
REPLICAS_LISTAS=<las réplicas listas del Deployment que instaló el chart>
```

<details>
<summary>Qué debería ver</summary>

helm search repo le muestra que la última versión del chart NO es la 6.13.0 (el día de la verificación la última era la 6.15.0), y esa es justamente la razón de fijar. helm show chart con --version 6.13.0 responde name: podinfo, version: 6.13.0 y appVersion: 6.13.0. La instalación termina diciendo STATUS: deployed y REVISION: 1. helm list en JSON trae "chart":"podinfo-6.13.0" y "app_version":"6.13.0". helm get values devuelve lo que usted pasó y nada más, {"replicaCount":3,"ui":{"message":`lo que pasa es que aqui si atienden`}}, porque get values muestra los valores que usted puso encima, no el archivo de valores completo del chart. El listado de Secrets muestra un objeto llamado sh.helm.release.v1.franquicia-del-barrio.v1 con ESTADO deployed, que es donde Helm guarda el registro del release; no hay ninguna base de datos aparte. El Deployment corre con imagen ghcr.io/stefanprodan/podinfo:6.13.0 y tres réplicas listas. Y la sonda cierra el círculo: la aplicación contesta un JSON donde ella misma reporta "version": "6.13.0" y "message": `lo que pasa es que aqui si atienden`.

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

- **Síntoma (step 1):** El rollout se queda pegado y nunca termina, con maxUnavailable en 0
  **Qué hacer:** Con maxUnavailable en 0 el controlador NO mata a nadie hasta que el Pod nuevo quede Ready, así que si el Pod nuevo no arranca, el rollout se queda ahí para siempre en vez de tumbarle el servicio. Eso es lo correcto, no un error. Mire por que no arranca con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get pods; si está en Pending y el clúster ya tiene los Pods del Paso 3 encima, puede que no quepa el quinto Pod, y ahí la respuesta es terminar el Paso 1 antes de montar el Paso 3, no aflojar la restricción.

- **Síntoma (step 1):** El API server rechaza el Deployment diciendo que maxSurge y maxUnavailable no pueden ser cero los dos
  **Qué hacer:** Es cierto y es a propósito: si nadie puede faltar y tampoco se puede crear ninguno de más, no hay forma física de reemplazar nada. Por eso la restricción del dueño le da margen por un lado (cinco caben, cuatro hay) aunque se lo quite por el otro. Si le salió ese error, usted puso los dos en cero; vuelva a leer la restricción y reparta.

- **Síntoma (step 1):** set image responde que no encontró el contenedor que usted nombró
  **Qué hacer:** El nombre del contenedor lo pone la plantilla del Pod, no el Deployment. En el manifiesto de este paso el contenedor se llama nginx, y por eso el comando dice nginx=. Confírmelo con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get deployment turno-de-almuerzo -o `jsonpath='{.spec.template.spec.containers[0].name}'` en vez de adivinarlo.

- **Síntoma (step 2):** rollout history no le muestra las tres revisiones, le muestra menos
  **Qué hacer:** Un Deployment solo guarda tantas revisiones viejas como diga su campo revisionHistoryLimit, y las que sobran se van borrando. Lea el valor real del suyo con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get deployment carta-de-la-semana -o `jsonpath='{.spec.revisionHistoryLimit}'` en vez de suponerlo. Si le quedaron menos de tres, es porque algún cambio no llegó a completar el rollout; revise que cada set image haya terminado con su rollout status antes del siguiente.

- **Síntoma (step 2):** El undo respondió que la revisión 2 no existe
  **Qué hacer:** Casi siempre es que dos de sus tres imágenes quedaron iguales, y entonces el segundo set image no generó revisión nueva porque la plantilla no cambió. Compare los digests de las tres imágenes línea por línea antes de repetir, y confirme cuántas revisiones hay con rollout history. Un Deployment solo crea revisión nueva cuando la PLANTILLA del Pod cambia; cambiar el número de réplicas, por ejemplo, no genera revisión.

- **Síntoma (step 3):** Uno de los dos Deployments no logra mantener sus réplicas, suben y bajan solas
  **Qué hacer:** Eso es la pelea de adopción, y pasa cuando los selectores de los DOS Deployments son iguales: cada controlador ve los Pods del otro como suyos y los mata para cuadrar su cuenta. El selector de cada Deployment tiene que incluir la etiqueta `version` para que sean disjuntos. Confírmelos con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n la-plaza get deployment -o `jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.selector.matchLabels}{"\n"}{end}'` y compare que no sean idénticos.

- **Síntoma (step 3):** La sonda devuelve siempre la misma cabecera Server, nunca ve la otra versión
  **Qué hacer:** Primero descarte lo probable: cuente los endpoints del Service con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n la-plaza get endpointslices -l kubernetes.io/service-name=el-restaurante -o yaml y mire si los Pods del canario están ahí. Si no están, o sus etiquetas no coinciden con el selector del Service, o sus Pods no están Ready todavía. Si SÍ están los diez y aun así solo contesta una versión, no es su YAML: es el reparto del sustrato, y por eso la comprobación trata ese caso como error de sustrato con nombre propio en vez de darle un aprobado que no significaría nada.

- **Síntoma (step 3):** Los diez Pods no caben y algunos quedan en Pending
  **Qué hacer:** Cada Pod de este paso pide 10m de CPU y 20Mi de memoria a propósito, para que los diez quepan al lado de los siete Pods de los Pasos 1 y 2. Si usted les subió los requests, no van a caber. Lea lo que ofrecen sus nodos con kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig get nodes -o `jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}'` antes de tocar nada.

- **Síntoma (step 4):** helm install falla diciendo que no encuentra el chart podinfo/podinfo
  **Qué hacer:** El repositorio se agrega por terminal, y este laboratorio lo guarda en un archivo de configuración propio dentro del workspace. Si usted abrió una terminal nueva, esas cinco variables HELM_ se perdieron y helm está mirando su configuración de siempre, donde el repositorio no está. Vuelva a exportarlas y corra helm repo list para confirmar que podinfo aparece antes de instalar.

- **Síntoma (step 4):** helm install falla diciendo que la versión 6.13.0 no está disponible
  **Qué hacer:** El índice del repositorio está en caché y puede estar viejo. Corra helm repo update y después helm search repo podinfo --versions para ver la lista real de versiones que su máquina conoce hoy, en vez de confiar en lo que diga este texto. Si la 6.13.0 ya no está publicada, escoja del listado una versión que NO sea la última, y use ese número de forma consistente en el comando y en su archivo de respuestas: la comprobación compara contra el valor fijado de 6.13.0, así que en ese caso avise antes de seguir en vez de inventar.

- **Síntoma (step 4):** El Deployment queda en ImagePullBackOff bajando la imagen desde ghcr.io
  **Qué hacer:** La imagen de este chart es publica y no necesita credencial, así que casi siempre el problema es una credencial VIEJA de ghcr.io guardada en su ~/.docker/config.json que el runtime intenta usar y el registro rechaza. Pruebe con un directorio de configuración de Docker aparte, por ejemplo exportando DOCKER_CONFIG hacia una carpeta vacía dentro de ~/ckad-lab/p02, y vuelva a crear el clúster; así el nodo baja la imagen de forma anónima.

## Para ir más lejos

- Vuelva al Deployment del Paso 1 y pruebe la restricción contraria: ponga maxSurge en 0 y maxUnavailable en 1, cambie la imagen y quédese leyendo la narración de rollout status. Va a ver el orden invertido, primero mata y después crea, y en algún momento va a haber solo tres puestos atendiendo. Es la estrategia correcta cuando el clúster no tiene sitio para un Pod de más, y es la incorrecta cuando el dueño le escribió la restricción del Paso 1.
- En el Deployment del Paso 2, ponga la anotación kubernetes.io/change-cause antes de cada cambio de imagen (el flag --record ya se retiró del kubectl moderno) y después mire como rollout history si llena la columna CHANGE-CAUSE. Es la única forma de que el historial le diga POR QUE se hizo cada revisión, y en un incidente real vale más que el número.
- Suba el canario del Paso 3 de dos réplicas a cinco y baje el estable de ocho a cinco, sin tocar el Service ni un solo campo, y vuelva a correr la sonda de cien peticiones. Va a ver la proporción moverse a la mitad y la mitad en vivo. Eso es lo que hace por dentro un despliegue progresivo: no hay magia, hay aritmética de réplicas. Después llévelo hasta el final, con el estable en cero, y note que el Service nunca dejó de responder.
- Haga helm upgrade del release del Paso 4 a la versión 6.14.1 del chart con --version, mire como helm list le sube la REVISION a 2 y como aparece un segundo Secret sh.helm.release.v1.franquicia-del-barrio.v2 al lado del primero. Después corra helm rollback y observe que Helm NO borra el Secret viejo ni reutiliza su número: crea una revisión 3. Compare ese comportamiento con el del rollout undo del Paso 2, donde Kubernetes SÍ reutiliza y renumera el ReplicaSet. Son dos sistemas de revisiones distintos y el examen los pregunta por separado.
- Renderice el mismo chart sin instalarlo, con helm template franquicia-del-barrio podinfo/podinfo --version 6.13.0 --set replicaCount=3, y compare la salida contra lo que hay vivo en el clúster. Después haga lo mismo con Kustomize: arme una base con el Deployment del Paso 1 y dos overlays, uno que suba las réplicas y otro que cambie la imagen, y renderice con kubectl kustomize. Los dos resuelven el mismo problema, plantillas contra parches, y el Capítulo 6 explica cuando conviene cada uno.

## Referencias

- Kubernetes Project, Deployments. The authority on the RollingUpdate strategy, on maxSurge and maxUnavailable including the rounding rule that a surge percentage rounds up and an unavailable percentage rounds down, on the deployment.kubernetes.io/revision annotation, on revisionHistoryLimit, and on the statement that rolling back reuses the existing ReplicaSet rather than creating a new one. This is the primary source for Steps 1 and 2. https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Kubernetes Project, kubectl rollout reference. Documents the status, history, undo and --to-revision subcommands driven in Step 2 and in the second extension. https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/
- Kubernetes Project, Canary deployments. Documents the pattern Step 3 builds: two Deployments carrying a common label plus a version label, fronted by a single Service whose selector names only the common label, with the traffic share coming out of each side's replica count. https://kubernetes.io/docs/concepts/workloads/management/
- Kubernetes Project, Service. Documents label selectors, how a Service pools every matching ready Pod into one set of backends, and the fact that a single Service in front of two Deployments is what makes the canary split happen. https://kubernetes.io/docs/concepts/services-networking/service/
- Kubernetes Project, EndpointSlices. Documents the kubernetes.io/service-name label, the endpoints[].conditions.ready field and the endpoints[].targetRef back-pointer to the owning Pod, which together are how Step 3's check counts live endpoints per version instead of trusting declared replicas. https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Helm Project, Using Helm. Documents helm repo add and update, helm install with --version to pin a chart, --set for individual values, --create-namespace, helm list and helm get values, and states that helm get values returns the user-supplied values rather than the chart's full defaults. The primary source for Step 4. https://helm.sh/docs/intro/using_helm/
- Helm Project, Helm Architecture. States that Helm stores release information as Secrets in the same namespace as the release, which is the sh.helm.release.v1.<release>.<revision> object Step 4's check reads as the proof a real release exists. https://helm.sh/docs/topics/architecture/
- Kubernetes Project, Declarative Management of Kubernetes Objects Using Kustomize. Documents bases, overlays and patches, the alternative to Helm templating compared in Chapter 6 and exercised in the last extension. https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
- podinfo Project, Helm chart and application. The source of the pinned chart used in Step 4, of its replicaCount and ui.message values, and of the JSON status endpoint on port 9898 through which the running application reports its own version and message. https://github.com/stefanprodan/podinfo
- kind Project, Configuration. Documents the kind.x-k8s.io/v1alpha4 Cluster config file, the nodes list with control-plane and worker roles, and the per-node image field used to pin the node image in this lab's setup. https://kind.sigs.k8s.io/docs/user/configuration/
- kind Project, Quick Start. Documents kind create cluster with --name, --config and --kubeconfig, and kind delete cluster, which is what keeps this lab's cluster and kubeconfig isolated from every other cluster on the machine. https://kind.sigs.k8s.io/docs/user/quick-start/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
