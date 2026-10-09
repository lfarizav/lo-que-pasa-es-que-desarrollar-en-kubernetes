# Parte I - Laboratorio: la receta que usted mismo empaca y mete al clúster, el encargo que se acaba en vez de repetirse para siempre, el pan que se hornea solo cada madrugada, y el ayudante que deja la nevera lista antes de que el cocinero abra

- Tiempo: 55 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solamente el objetivo y el entregable, y la secuencia exacta de comandos vive en el campo cmd de ese paso para que usted la revele después de haber intentado por su cuenta. El Paso 1 le hace empacar una receta: construye una imagen con docker a partir del Dockerfile que el setup le deja en el disco, la mete al clúster kind con kind load docker-image, y la pone a trabajar como un Deployment de dos réplicas, y la calificación exige que el contenedor que está corriendo venga de ESA imagen y no de uno pública que usted haya bajado para salir del paso (Capítulo 1). El Paso 2 le hace escoger el tipo de negocio: hay una tarea por lotes que tiene que terminar, y la respuesta correcta es un Job con completions y backoffLimit, no un Deployment; la comprobación exige que el trabajo lo haya hecho un Job, que el Job esté completo, y que en el namespace no haya quedado ni un Deployment ni un ReplicaSet haciendo de suplente (Capítulo 2). El Paso 3 le hace programar el pan de la madrugada con un CronJob que tiene horario y límites de historial, y la comprobación no se conforma con que el objeto exista: exige que ya haya disparado, que los Jobs sean de él y no hechos a mano, y que el límite de historial siga puesto y siga mandando (Capítulo 2). El Paso 4 cierra con el ayudante de cocina: un init container que deja el trabajo hecho en una nevera compartida de tipo emptyDir, y un contenedor principal que sirve ese mismo archivo, con la comprobación entrando al contenedor principal a leer el archivo y a pedirlo por HTTP (Capítulo 3). Ninguna comprobación lee su historial de comandos: las cuatro vuelven a consultar el clúster vivo en el momento de calificar, tres de ellas entran a un contenedor a mirar con sus propios ojos, y la primera además abre el containerd del nodo para confirmar de dónde salió la imagen.

## Prerrequisitos

- Una máquina Linux con kind, kubectl, docker y jq en el PATH, y con al menos 3 GB de RAM libres para el clúster. El laboratorio crea su propio clúster kind llamado ckad-p01 y lo elimina en el teardown.
- AISLAMIENTO, y esto no es un detalle de estilo. El clúster de este laboratorio NUNCA toca su kubeconfig de siempre: se crea con --kubeconfig ~/ckad-lab/p01/kubeconfig desde el primer comando, y absolutamente todos los kubectl del laboratorio pasan --kubeconfig y --context explícitamente. Si usted ya tiene otros clústeres de kind corriendo en esta máquina, este laboratorio no los ve, no los modifica y no los borra. Compruébelo usted mismo: al final del setup se imprime un kubectl config get-contexts sin --kubeconfig, y ahí no debe aparecer ni rastro de ckad-p01.
- Acceso a internet en el momento de montar el laboratorio y durante los Pasos 2, 3 y 4: kind descarga la imagen del nodo, y el containerd del nodo descarga la imagen de busybox fijada por digest que usan el Job, el CronJob y el Pod con init container. El Paso 1 es el único que NO necesita registro, porque su imagen se construye en su máquina y se empuja al nodo con kind load. El demonio de Docker tiene que estar corriendo todo el tiempo, porque tanto el Paso 1 como su comprobación hablan con él.
- VERSIONES FIJADAS, verificadas el 2026-08-21 en esta misma máquina. kind v0.32.0. kubectl v1.36.1. Docker 29.7.2. jq 1.7. Imagen del nodo kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, que es la imagen por defecto de esa versión de kind y que aquí se pasa explícita con --image porque un tag es mutable y un digest no. Imagen base de la receta y de los tres pasos siguientes busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirme lo que le quedó instalado con kind version y con kubectl version, nunca de memoria.
- Haber leído los Capítulos 1 a 3. Este laboratorio no vuelve a explicar qué es una imagen de contenedor, ni cuándo se usa un Job en lugar de un Deployment, ni para qué sirve un init container; le hace operar las tres cosas contra un clúster real y le califica el estado final.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 1: La receta se empaca una vez y se lleva a la cocina, no se le pide prestada al vecino (10 pts)

El Capítulo 1 le explicó que una imagen de contenedor es la receta empacada: no es el plato servido, es todo lo que hace falta para que cualquier cocina del mundo prepare ese plato igualito. Lo que pasa es que entre entender eso y hacerlo hay un paso que es fácil pasar por alto, y es el más aburrido y el más importante: la receta tiene que llegar físicamente a la cocina donde se va a cocinar.

El clúster no se asoma a su computador a ver qué construyó usted. El kubelet, cuando le mandan un Pod, va a buscar esa imagen a un registro, y si el nombre no existe allá le devuelve un ImagePullBackOff sin la menor compasión. Por eso kind trae un comando específico para el desarrollo local, kind load docker-image, que agarra la imagen del docker de su máquina y la empuja al containerd del nodo. Es como cargar la olla en el carro y llevarla al restaurante.

Y aquí viene el detalle que hace clic. Cuando usted mire el imageID del Pod, no va a ver el nombre que usted le puso. Va a ver algo que dice import con la fecha de hoy pegada. Ese nombre raro es la firma de que esa imagen entró por la puerta de atrás, cargada a mano, y no por el registro. Un contenedor bajado de docker.io jamás se ve así, y por eso ese campo es la prueba más honesta de que usted sí hizo el trabajo.

El otro detalle que se le va a quedar es el nombre largo. Usted escribe la-receta:1.0, y el containerd del nodo lo lista como docker.io/library/la-receta:1.0, porque todo nombre corto se normaliza a esa forma. No es que alguien haya subido su imagen a Docker Hub: es que ese prefijo es el valor por defecto del nombre, no una dirección de descarga.

Y por último, la política de descarga. Usted no la va a escribir y de todos modos va a salir IfNotPresent. Eso pasa porque el tag no es latest. Si a esa imagen usted le hubiera puesto el tag latest, la política por defecto habría sido Always, el kubelet habría salido a buscarla al registro, y el Pod se le habría caído aunque la imagen estuviera ahí mismo en el nodo. Esa es la razón por la que este paso le prohíbe Always: no es capricho, es cómo funciona el desarrollo local con kind.

ENTREGABLE: la imagen `la-receta:1.0` construida a partir de `~/ckad-lab/p01/receta/Dockerfile`, cargada en el clúster ckad-p01, y un Deployment llamado `el-restaurante` en el namespace `la-cocina` con 2 réplicas listas, cuyo contenedor pide esa misma imagen y NO usa imagePullPolicy Always. Además el archivo `~/ckad-lab/p01/01-respuesta.txt`, de 4 líneas:

```text
REPLICAS_LISTAS=<cuántas réplicas reporta el Deployment como listas>
IMAGEN_DEL_DESPLIEGUE=<la imagen que piden los Pods, tal cual aparece en el spec>
IMAGEN_EN_EL_NODO=<el nombre completo con el que el containerd del nodo lista esa imagen>
LO_QUE_SIRVE_LA_CARTA=<la línea de texto que el contenedor devuelve en el puerto 8080>
```

<details>
<summary>Qué debería ver</summary>

El Dockerfile que le dejó el setup empieza por un FROM de busybox fijado por digest, crea /carta, copia carta.html adentro como index.html y termina con un CMD que levanta el httpd de busybox en el puerto 8080 sirviendo esa carpeta. El docker build termina con la línea naming to docker.io/library/la-receta:1.0, y docker image ls le muestra la imagen recién nacida. El kind load imprime que la imagen con ese ID no estaba todavía en el nodo ckad-p01-control-plane y que la está cargando. Después el crictl del nodo ya la lista, y fíjese bien en cómo la lista: no dice la-receta:1.0 a secas, dice docker.io/library/la-receta, porque containerd normaliza todo nombre corto a esa forma larga. El rollout termina con successfully rolled out. Y la línea que vale la pena leer es la de los Pods: la política de descarga salió IfNotPresent sola, sin que usted la escribiera, porque el tag no es latest, y el imageID no dice la-receta por ningún lado sino docker.io/library/import-<fecha de hoy>@sha256:<lo que sea>. Ese nombre import con la fecha es la huella de kind load: una imagen bajada de un registro jamás se vería así. El último comando le devuelve la carta: la-carta-del-restaurante-v1.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 2: Un encargo se entrega y se acaba, no se queda abierto toda la vida (10 pts)

El Capítulo 2 le puso el catálogo de negocios sobre la mesa: el Deployment para lo que tiene que estar siempre abierto, el DaemonSet para lo que va uno por sede, el StatefulSet para lo que tiene nombre propio y bodega propia, y el Job para lo que se hace y se acaba. Lo que pasa es que en la vida real uno no escoge de una lista, uno escoge por reflejo, y el reflejo más a la mano es el Deployment.

Y ese reflejo falla aquí. Un Deployment tiene una obsesión escrita en su naturaleza: mantener N réplicas vivas. Si su proceso hace su trabajo y termina bien, con código de salida 0, el Deployment lo lee como una caída y lo vuelve a levantar. Y otra vez. Y otra vez. Usted acaba con un contenedor en CrashLoopBackOff que en realidad nunca falló ni una sola vez, y con un log lleno de éxitos que el clúster interpreta como desastres. Es contratar a alguien de planta para que lleve un solo almuerzo, y despedirlo y volverlo a contratar cada vez que llega.

El Job existe justamente para eso. Usted le dice cuántas veces tiene que salir bien la cosa con completions, cuántas al tiempo con parallelism, y cuántos reintentos aguanta antes de rendirse con backoffLimit. Ese último es fácil de dar por sentado, y le va a sorprender el valor por defecto cuando lo mire con explain: no es 0, no es 1.

Y hay una consecuencia práctica que vale por todo el capítulo: cuando el Job termina, los Pods NO se borran. Se quedan en fase Succeeded con su log completo, esperando a que usted los lea. Por eso un Job se depura y un Deployment que hace trabajo por lotes no: en el Deployment el Pod que le interesa ya fue reemplazado tres veces antes de que usted alcanzara a escribir kubectl logs.

Este paso le pide procesar los seis encargos del almuerzo. Escoja el negocio.

ENTREGABLE: en el namespace `los-encargos`, un Job llamado `los-encargos-del-almuerzo` con `completions: 6` y `backoffLimit: 2`, ya completado, cuyos seis Pods sigan existiendo en fase Succeeded. En ese namespace NO puede quedar ningún Deployment, ReplicaSet, StatefulSet ni DaemonSet, y el Job NO puede llevar ttlSecondsAfterFinished. Además el archivo `~/ckad-lab/p01/02-respuesta.txt`, de 3 líneas:

```text
DUENO_DE_LOS_PODS=<el Kind que aparece en ownerReferences de los Pods del namespace>
ENCARGOS_COMPLETADOS=<cuántos Pods reporta el Job como exitosos>
REINTENTOS_PERMITIDOS=<el valor de backoffLimit que quedó en el Job>
```

<details>
<summary>Qué debería ver</summary>

El api-resources del grupo batch le muestra que ahí viven solo dos cosas, cronjobs y jobs, y nada más. El explain de completions le dice que es el número de Pods que tienen que terminar bien para que el Job se dé por cumplido, y el de backoffLimit le da un dato que conviene mirar en vez de suponer: por defecto son 6 reintentos, no 0 y no 1. Después el Job se crea y el wait devuelve condition met en menos de un minuto. La línea de estado dice 6 completions, backoffLimit 2, exitosos 6. Los seis Pods aparecen listados en fase Succeeded, no Running, y en los seis el dueño es Job: fíjese en que los Pods NO desaparecen cuando el Job termina, se quedan ahí con su log intacto, que es justamente lo que hace a un Job depurable y a un Deployment no. Y la última línea es la más elocuente de todas: No resources found in los-encargos namespace, porque en este namespace no hay ni un Deployment, ni un ReplicaSet, ni un StatefulSet, ni un DaemonSet. El trabajo lo hizo un Job solo.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 2: El pan de la madrugada se hornea solo, y la panadería no guarda todas las bandejas de la historia (10 pts)

Un Job es un encargo. Un CronJob es la costumbre. Lo que pasa es que en el restaurante hay cosas que no se piden: el pan de la madrugada sale todos los días a la misma hora porque siempre ha sido así, y nadie tiene que llamar al panadero para recordárselo.

Un CronJob no hace el trabajo. Es importante que eso quede claro, porque es fácil confundirlo: el CronJob es una fábrica de Jobs. Cuando le llega su minuto, crea un Job, y ese Job crea el Pod que sí hace el trabajo. Por eso la cadena de ownerReferences tiene tres eslabones y no dos, y por eso los nombres de los Jobs le salen con un número largo pegado al final, que no es aleatorio: es el minuto exacto en que le tocaba correr.

Hay una parte que es fácil dejar en su valor por defecto hasta que se le llena el clúster: el CronJob no borra su pasado solo porque sí. Guarda un historial de Jobs terminados, y ese historial tiene un valor por defecto que usted tiene que ir a mirar con explain en vez de suponerlo. Un CronJob que corre cada minuto y que nadie limitó le deja una pila de objetos muertos en el namespace, y el día que usted vaya a listar Jobs no va a encontrar el que le importa. La panadería no guarda todas las bandejas que ha usado en su vida: guarda las últimas y bota el resto.

Hay un detalle de paciencia que también es de examen: un CronJob recién creado NO corre en ese instante. Corre cuando le llegue su minuto según el horario. Por eso este paso usa un horario de cada minuto, para que usted alcance a ver el ciclo completo sin quedarse dormido esperando, y por eso el comando del paso se queda esperando en un bucle hasta que status.lastScheduleTime deje de estar vacío.

ENTREGABLE: en el namespace `la-madrugada`, un CronJob llamado `el-pan-de-la-madrugada` con `schedule: "*/1 * * * *"`, `successfulJobsHistoryLimit: 2` y `failedJobsHistoryLimit: 1`, sin suspender, que YA haya disparado al menos una vez y tenga al menos un Job propio terminado con éxito. En ese namespace no puede quedar ningún Job hecho a mano, o sea sin ownerReferences. Además el archivo `~/ckad-lab/p01/03-respuesta.txt`, de 3 líneas:

```text
HORARIO_DEL_PAN=<el valor exacto del campo schedule>
HISTORIAL_DE_EXITOSOS=<cuántos Jobs exitosos guarda el CronJob>
DUENO_DE_LOS_EMPLEOS=<el Kind que aparece en ownerReferences de los Jobs del namespace>
```

<details>
<summary>Qué debería ver</summary>

Los tres explain le entregan los tres datos que este paso necesita y que conviene leer en vez de recordar: schedule usa la sintaxis de cron, successfulJobsHistoryLimit guarda por defecto 3 Jobs exitosos, y failedJobsHistoryLimit guarda por defecto 1 fallido. El CronJob se crea y el primer get le muestra una tabla con SCHEDULE, TIMEZONE en none, SUSPEND en False, ACTIVE en 0 y LAST SCHEDULE en none, porque todavía no ha disparado. Por eso el laboratorio se queda esperando: un CronJob recién creado no corre de una, corre cuando le llegue su minuto. Al minuto o menos, la línea de estado ya trae una marca de tiempo real en última. El listado de Jobs le muestra uno solo, con un nombre que es el del CronJob más un número largo pegado, y con dueño=CronJob: ese número es el minuto de Unix en que le tocaba correr, y por eso dos ejecuciones nunca chocan de nombre. El campo exitosos puede salir vacío si usted alcanzó a mirar mientras el Pod todavía estaba trabajando; vuelva a mirar en unos segundos y dice 1. El logs le imprime la línea del panadero con la hora UTC de la horneada.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 3: El ayudante deja la nevera lista y se va, y el cocinero encuentra todo servido (10 pts)

El Capítulo 3 le presentó al ayudante de cocina: ese que llega antes que todo el mundo, pica, lava, deja las ollas listas, y cuando el cocinero abre la puerta ya no está. En Kubernetes ese señor se llama init container, y su trabajo es preparar el terreno.

Lo que pasa es que un init container no es un contenedor más pequeño ni un contenedor de menor categoría. Es un contenedor que corre ANTES, en orden, uno detrás de otro, y que tiene que terminar bien para que el siguiente empiece. Si el ayudante se cae, el cocinero no abre. Nunca. El Pod se queda en Init con el número del que falló, y ahí no hay nada que reiniciar salvo el ayudante mismo.

Y aquí viene la pregunta que separa la teoría de la práctica: si el ayudante se va antes de que el cocinero llegue, ¿cómo le entrega el trabajo? No se lo pasa por la puerta. Cada contenedor tiene su propio sistema de archivos aislado, así que lo que el ayudante escriba en su disco se va con él. La entrega se hace en la nevera compartida: un volumen emptyDir montado por los dos.

El emptyDir es lo que dice el nombre. Nace vacío cuando el Pod aterriza en un nodo, vive mientras el Pod viva, y se borra sin ceremonia cuando el Pod se va. No es almacenamiento, es una mesa de trabajo compartida entre los contenedores de un mismo Pod. Y note el efecto que a veces sorprende: si el contenedor principal tenía un archivo en esa ruta metido en su imagen, el montaje del emptyDir se lo tapa. Por eso este paso no se puede resolver horneando el archivo en la imagen.

ENTREGABLE: en el namespace `la-nevera`, un Pod llamado `el-almuerzo-del-dia`, en Running y Ready, con estas condiciones: un volumen de tipo `emptyDir` montado tanto por el init container como por el contenedor principal; un init container que termine con razón Completed y código 0 y que deje en ese volumen un archivo `index.html` cuya única línea sea `el-ayudante-dejo-listo-el-mise-en-place`; un contenedor principal que sirva esa misma carpeta por HTTP en el puerto 8080 del contenedor. Los dos contenedores tienen que usar la imagen fijada `busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0`. Además el archivo `~/ckad-lab/p01/04-respuesta.txt`, de 3 líneas:

```text
ESTADO_DEL_AYUDANTE=<la razón con la que terminó el init container>
TIPO_DE_VOLUMEN=<el tipo del volumen que comparten los dos contenedores>
LO_QUE_SIRVE_LA_COCINA=<la línea que devuelve el contenedor principal en el puerto 8080>
```

<details>
<summary>Qué debería ver</summary>

Los dos explain le confirman lo que el capítulo prometió: los init containers corren en orden, antes de los contenedores normales, y si uno falla el Pod se da por fallido y se maneja según su restartPolicy; y un emptyDir es un directorio temporal que vive lo mismo que el Pod. El Pod se crea y el wait devuelve condition met en unos segundos. El estado del init container dice el-ayudante -> Completed, y esa palabra es importante: no dice Running ni Succeeded, dice Completed, porque un init container terminado se reporta en el bloque terminated con esa razón. El listado de volúmenes le muestra dos, y ahí hay una sorpresa útil: además de su volumen la-nevera de tipo emptyDir aparece uno llamado kube-api-access-<algo> de tipo projected, que usted no escribió y que Kubernetes le mete a todo Pod para entregarle el token de su ServiceAccount. Los dos últimos comandos devuelven la misma línea, el-ayudante-dejo-listo-el-mise-en-place: la primera leyendo el archivo desde el sistema de archivos del cocinero, la segunda pidiéndoselo al httpd por el puerto 8080. Que las dos coincidan es la demostración completa: el ayudante escribió, el cocinero lo tiene, y lo está sirviendo.

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

- **Síntoma (step 1):** Los Pods se quedan en ErrImagePull o ImagePullBackOff aunque usted construyó la imagen
  **Qué hacer:** Son dos causas y conviene separarlas. La primera: se le olvidó el kind load, o lo hizo contra otro clúster. Compruébelo mirando dentro del nodo con docker exec ckad-p01-control-plane crictl images, que es la única fuente que dice la verdad sobre lo que el nodo tiene; si ahí no aparece, el docker de su máquina no cuenta. La segunda: la imagen sí está en el nodo pero usted dejó imagePullPolicy en Always, y entonces el kubelet ignora lo que ya tiene y sale a buscarla a docker.io, donde no existe. Con un tag distinto de latest la política por defecto ya es IfNotPresent, así que lo normal es no escribirla.

- **Síntoma (step 1):** kind load falla con ctr: content digest ... not found
  **Qué hacer:** Ese error sale cuando la imagen que usted le pasa es un índice multiplataforma del que su docker solo tiene bajada una plataforma, que es lo que pasa si intenta cargar busybox directamente. La imagen que este paso le pide cargar es la que usted construye, y esa sale de una sola plataforma, así que carga sin problema. Si de todas formas se topa con el error, reconstruya con docker build --platform linux/amd64 o con DOCKER_BUILDKIT=0. El setup ya le hizo esta misma prueba y le habría dicho ERROR DE SUSTRATO: KIND-LOAD-NO-FUNCIONA antes de dejarlo empezar.

- **Síntoma (step 1):** El wget dentro del Pod no devuelve nada o dice connection refused
  **Qué hacer:** Revise que está pidiendo el puerto 8080 y no el 80: el httpd de busybox solo escucha donde le digan con -p, y el Dockerfile del setup dice 8080. Y recuerde que EXPOSE en un Dockerfile es pura documentación, no abre nada ni publica nada en Kubernetes; el puerto queda abierto porque el proceso lo abre, no porque el Dockerfile lo mencione.

- **Síntoma (step 2):** El Job se crea pero es rechazado con un error sobre restartPolicy
  **Qué hacer:** La plantilla de Pod de un Job solo acepta restartPolicy Never o OnFailure, nunca Always, que es el valor por defecto de un Pod normal. Si usted copió una plantilla de un Deployment y no le tocó ese campo, ahí está el error. Escriba restartPolicy: Never dentro de spec.template.spec, que es donde va, no dentro del spec del Job.

- **Síntoma (step 2):** kubectl wait --for=condition=Complete se queda esperando para siempre
  **Qué hacer:** Mire los Pods primero con kubectl -n los-encargos get pods. Si están en ImagePullBackOff, el nodo no pudo traer la imagen y el problema no es el Job. Si están en Error, su comando devolvió un código distinto de cero y el Job va a reintentar hasta agotar el backoffLimit y después marcar la condición Failed en vez de Complete. Lea el log de un Pod fallido con kubectl -n los-encargos logs <pod>, que para eso los Pods de un Job no se borran.

- **Síntoma (step 2):** Usted borró y volvió a crear el Job y ahora kubectl apply se queja de campos inmutables
  **Qué hacer:** El selector y la plantilla de un Job ya creado no se pueden editar, igual que roleRef en RBAC. Cuando se equivocó en completions o en backoffLimit, la única salida es kubectl delete job <nombre> y volver a aplicar el manifiesto corregido. Borre con --wait=true para que los Pods viejos se vayan antes de crear el nuevo, o va a ver Pods de dos generaciones al mismo tiempo y la comprobación va a contar de más.

- **Síntoma (step 3):** LAST SCHEDULE se queda en none y no aparece ningún Job
  **Qué hacer:** Lo primero es paciencia: con un horario de cada minuto puede tardar hasta 60 segundos, y el controlador revisa en ciclos, así que 70 u 80 segundos tampoco son raros. Si pasa mucho más, revise dos campos. suspend tiene que estar en false, y si usted lo puso en true el objeto existe pero no dispara nunca. Y revise que el horario tenga cinco campos separados por espacios: un schedule mal escrito es rechazado al crear, pero uno bien escrito y raro, como 0 3 1 1 *, es aceptado y sencillamente no le va a tocar el turno hoy.

- **Síntoma (step 3):** Los Jobs se acumulan y ya hay diez en el namespace
  **Qué hacer:** Es el síntoma exacto de no haber puesto los límites de historial, o de haberlos puesto en el sitio equivocado. Van en spec del CronJob, al mismo nivel que schedule, NO dentro de jobTemplate. Un kubectl -n la-madrugada get cronjob el-pan-de-la-madrugada -o yaml le muestra dónde quedaron. Cuando los corrija con un apply, el controlador recoge el exceso solo en el siguiente ciclo, no hay que borrar nada a mano.

- **Síntoma (step 3):** kubectl logs no encuentra nada aunque el Job dice que salió bien
  **Qué hacer:** Probablemente el Pod de esa horneada ya fue recogido junto con su Job por el límite de historial, que es precisamente el comportamiento que este paso le hace configurar. Liste los Jobs vivos primero con kubectl -n la-madrugada get jobs y pida el log del más reciente. La etiqueta que amarra un Pod a su Job es batch.kubernetes.io/job-name, y sirve para pedir logs por selector sin tener que copiar nombres a mano.

- **Síntoma (step 4):** El Pod se queda en Init:0/1 o en Init:Error y nunca llega a Running
  **Qué hacer:** El ayudante no terminó bien y el cocinero no va a abrir hasta que termine. Pida el log del init container por nombre, que kubectl no lo muestra si no se lo pide: kubectl -n la-nevera logs el-almuerzo-del-dia -c el-ayudante. Un error posible es escribir en una ruta que no está montada, por ejemplo montar el volumen en /nevera pero escribir en /nevera/html/index.html sin que ese subdirectorio exista. Recuerde que el comando corre en un shell del contenedor, así que si necesita mkdir -p, póngalo antes en la misma línea.

- **Síntoma (step 4):** El cocinero está Running pero el wget devuelve 404 File not found
  **Qué hacer:** El archivo no está donde el httpd lo busca. Compare tres cosas: el mountPath del volumen en el contenedor principal, la ruta que el httpd recibe con -h, y la ruta donde el init container escribió. Las tres tienen que apuntar al mismo sitio. Un error clásico es montar el mismo volumen en dos rutas distintas en cada contenedor, que Kubernetes acepta sin chistar porque es perfectamente legal, y el archivo sí está, solo que en otra dirección de la que el cocinero mira.

- **Síntoma (step 4):** kubectl exec le responde que hay que elegir un contenedor
  **Qué hacer:** Un Pod con varios contenedores obliga a decir a cuál se entra, con -c <nombre>. Y ojo con este detalle: al init container ya terminado NO se le puede hacer exec, porque su proceso no existe; de ese solo se pueden leer los logs. La prueba de que la entrega funcionó se hace siempre desde el contenedor principal, que es el que está vivo y el que tiene la nevera montada.

## Para ir más lejos

- Rompa el Paso 1 a propósito para ver el problema completo. Vuelva a etiquetar su imagen como la-receta:latest, cree un Deployment nuevo con ese tag, y mire qué política de descarga le sale sin que usted la escriba y qué hace el Pod. Después arréglelo de las dos maneras posibles, poniendo imagePullPolicy: IfNotPresent a mano o volviendo a un tag con versión, y quédese con la conclusión: en desarrollo local el tag latest no es un nombre, es una orden de salir a internet.
- Haga a propósito lo que el Paso 2 le prohíbe y véalo con sus ojos. Cree un Deployment con la misma imagen y el mismo comando del Job, con una sola réplica, y quédese mirando kubectl get pods -w durante un minuto. Cuente los reinicios. Lea el log del Pod y compruebe que el proceso salió bien todas las veces. Ahora ya sabe por qué CrashLoopBackOff no siempre significa que algo falló: a veces significa que algo terminó, en un sitio donde terminar está prohibido.
- Póngale al CronJob del Paso 3 un jobTemplate que falle siempre, con un comando que salga con código 1, y déjelo correr cinco minutos. Cuente cuántos Jobs fallidos quedan retenidos y compárelo con failedJobsHistoryLimit. Después juegue con concurrencyPolicy: ponga un comando que tarde 90 segundos con un horario de cada minuto y compare qué pasa con Allow, con Forbid y con Replace. Los tres valores están documentados en el explain del campo y cada uno cuenta una historia distinta sobre qué hacer cuando la horneada anterior todavía está en el horno.
- Amplíe el Paso 4 a dos ayudantes y compruebe el orden. Agregue un segundo init container que escriba una segunda línea en el mismo archivo con >>, póngalo primero en la lista y después póngalo segundo, y compare el archivo resultante: el orden de la lista es el orden de ejecución y no hay nada que negociar. Después haga que el primero salga con código 1 y mire con kubectl describe pod dónde se queda el Pod y qué dice el estado del segundo ayudante, que ni siquiera va a haber empezado.

## Referencias

- Kubernetes Project, Images. The basis of Step 1: image names, the docker.io/library normalization of short names, and the imagePullPolicy defaults, including the rule that the default is Always for the latest tag and IfNotPresent for any other tag. https://kubernetes.io/docs/concepts/containers/images/
- kind Project, Quick Start. Documents kind create cluster with --name, --image and --kubeconfig, kind delete cluster, the kind-<name> context naming, the <name>-control-plane node container naming, and kind load docker-image as the supported way to get a locally built image into the cluster's containerd. https://kind.sigs.k8s.io/docs/user/quick-start/
- Docker Inc., Dockerfile reference. The authority for the instructions in the Dockerfile the setup writes for Step 1: FROM with a digest, RUN, COPY, EXPOSE as documentation only, and CMD in exec form. https://docs.docker.com/reference/dockerfile/
- Kubernetes Project, Jobs. The basis of Step 2: completions, parallelism, backoffLimit and its default, the Complete condition, the restriction of the Pod template's restartPolicy to Never or OnFailure, and the fact that finished Pods are retained until the Job is deleted or ttlSecondsAfterFinished collects them. https://kubernetes.io/docs/concepts/workloads/controllers/job/
- Kubernetes Project, Deployments. The contrast case in Step 2: a Deployment keeps a declared number of replicas running, which is why a process that exits successfully is restarted rather than considered done. https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Kubernetes Project, CronJob. The basis of Step 3: the schedule field's cron syntax, successfulJobsHistoryLimit and failedJobsHistoryLimit with their defaults, suspend, concurrencyPolicy, and the fact that a CronJob creates Jobs rather than Pods. https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- Kubernetes Project, Running Automated Tasks with a CronJob. The task-level walkthrough behind Step 3, including the generated Job naming and the wait before the first scheduled run. https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/
- Kubernetes Project, Init Containers. The basis of Step 4: init containers run to completion in the order declared, each must succeed before the next starts, the app containers do not start until all of them finish, and the terminated status is where a finished init container is reported. https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
- Kubernetes Project, Volumes. The reference for emptyDir in Step 4: it is created empty when the Pod is assigned to a node, is shared by the containers of that Pod, and is deleted permanently when the Pod is removed from the node. https://kubernetes.io/docs/concepts/storage/volumes/
- Kubernetes Project, Pods. Documents the shared context of a Pod and the fact that its containers each keep their own filesystem, which is why the Step 4 handover has to happen through a shared volume rather than through the container filesystems. https://kubernetes.io/docs/concepts/workloads/pods/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
