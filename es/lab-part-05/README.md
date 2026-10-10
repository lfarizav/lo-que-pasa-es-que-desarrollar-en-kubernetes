# Parte V - Laboratorio: el domicilio que sí sabe llegar, la heladería que se cambió de sede y nadie actualizó el pedido, un local que solo le abre al mensajero con carnet, y un directorio en la entrada que manda a cada quien a su local

- Tiempo: 45-60 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo, y la secuencia exacta de comandos vive en el campo cmd de ese paso, para que usted la revele después de haber intentado primero por su cuenta. El Paso 1 le hace exponer un Deployment con un Service ClusterIP y demostrar dos cosas distintas que casi todo el mundo confunde: que el EndpointSlice se llenó con las direcciones vivas de los Pods, y que un Pod cliente resuelve el nombre completo del Service por el DNS del clúster y recibe respuesta HTTP por ese nombre (Capítulo 13). El Paso 2 le entrega un Service que el montaje dejó roto a propósito, codificado en base64 para que usted no lo lea de una ojeada: no tiene ni un endpoint y usted tiene que diagnosticar por qué. Aquí, a diferencia de otros laboratorios, se le permite arreglarlo por cualquiera de los dos lados, y el enunciado le dice con toda claridad cuál es el estado final que se califica. El Paso 3 es el que separa este laboratorio de un blog: usted mide primero que el tráfico entre Pods pasa sin restricción, aplica una negación por defecto más una regla que abre una sola puerta por etiqueta, y demuestra con códigos de salida que el mensajero con carnet entra y el vendedor ambulante se queda esperando (Capítulo 15). El Paso 4 cierra con la entrada principal: un Ingress con dos rutas hacia dos Services distintos, comprobado con un curl real atravesando el controlador (Capítulo 14). Ninguna comprobación lee su historial: todas vuelven a consultar el clúster y tres de ellas generan tráfico nuevo en el momento de calificar.

## Prerrequisitos

- Una máquina Linux con kind, kubectl, docker, curl y base64 en el PATH, y con al menos 4 GB de RAM libres. El laboratorio crea su propio clúster kind llamado ckad-p05 y escribe su kubeconfig en un archivo privado, ~/ckad-lab/p05/kubeconfig, que no es el suyo de siempre. Todos los comandos pasan --kubeconfig apuntando a ese archivo, así que su ~/.kube/config no se modifica y ningún otro clúster suyo se toca. El teardown borra únicamente el clúster ckad-p05 y la carpeta ~/ckad-lab/p05.
- Los puertos 8085 y 8543 del host libres. El clúster se crea con extraPortMappings que llevan el 8085 del host al puerto 80 del nodo y el 8543 al 443, que es por donde usted entra al centro comercial en el Paso 4. Se escogieron esos números a propósito, y no el 8080 de siempre, porque el 8080 suele estar ocupado por otra cosa en una máquina de trabajo. Confirme con ss -ltn antes de empezar; si alguno está ocupado, cambie el número en kind-p05.yaml y en los comandos del Paso 4.
- Acceso a internet en el momento de montar el laboratorio: el setup descarga los manifiestos de Calico y del controlador de Ingress, y las imágenes de contenedor de quay.io, registry.k8s.io y docker.io. La calificación en sí no necesita internet, solo el clúster vivo y el puerto 8085 del host.
- IMAGEN DEL NODO FIJADA POR DIGEST, leída del propio binario de kind v0.32.0 el 2026-08-21: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5. Las notas de versión de kind dicen que hay que usar el digest @sha256 para garantizar una imagen construida para esa versión, no solo el tag. Confirme la suya con kind version y con docker images --digests, nunca de memoria. Esa ya no es la imagen por defecto: el binario de kind v0.33.0, con el que se ejecutó este laboratorio el 2026-10-09, trae kindest/node:v1.37.0, y por eso kind-p05.yaml declara la imagen fijada.
- CNI FIJADO: Calico v3.32.1, publicada el 2026-06-26. Es una versión fijada a propósito y no la más nueva: al 2026-10-09 el proyecto ya publicó la v3.32.2 y la v3.33.0, según sus releases en GitHub, y este laboratorio se ejecutó completo con la v3.32.1 ese mismo día. Esta pieza no es decoración. El clúster se crea con disableDefaultCNI en true precisamente porque el CNI que kind trae de fábrica no aplica NetworkPolicy, y sin un CNI que la aplique el Paso 3 entero sería teatro. Ojo con un detalle que se paga caro: el archivo custom-resources.yaml que publica Calico trae por defecto un pool de IPs en 192.168.0.0/16, que es el rango de casi toda red casera y choca con la LAN. Por eso este laboratorio no usa ese archivo: escribe su propio recurso Installation con cidr 10.244.0.0/16, el mismo podSubnet que se le declara a kind. Confirme el pool que quedó vivo con kubectl get ippools -o wide.
- EL SETUP MIDE EL SUSTRATO, no lo asume. Antes de entregarle el laboratorio, el montaje levanta un namespace de prueba desechable, comprueba que un Pod le habla a otro sin ninguna política, aplica una negación total, y vuelve a probar. Si el tráfico SIGUE pasando, el setup imprime el error con nombre ERROR SUSTRATO-SIN-NETWORKPOLICY y termina con código distinto de cero, porque en ese clúster el Paso 3 no probaría absolutamente nada. Es la única forma honesta de montar un laboratorio de NetworkPolicy: un objeto puede ser aceptado por la API y no ser aplicado por nadie.
- CONTROLADOR DE INGRESS FIJADO, y aquí hay que decir la verdad completa: ingress-nginx controller-v1.15.1, publicado el 2026-03-19, es la ÚLTIMA versión que existirá. El proyecto kubernetes/ingress-nginx fue retirado y su repositorio está archivado en modo solo lectura; no habrá más correcciones de errores ni parches de seguridad, nunca. Verificado el 2026-10-09 contra la API de GitHub, que reporta archived true para ese repositorio y no lista ninguna release posterior. El manifiesto sigue descargándose porque un repositorio archivado no se borra, y el laboratorio lo usa a propósito, con el pin explícito, porque Ingress sigue en el temario del CKAD y porque saber que el centro comercial se quedó sin la empresa que le hacía mantenimiento a la entrada es el tipo de cosa que un desarrollador tiene que saber antes de proponerlo en producción.
- IMÁGENES DE APLICACIÓN FIJADAS POR DIGEST, verificadas el 2026-08-21 con docker buildx imagetools inspect: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de para los servidores web, y busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 para los Pods cliente, que es la imagen que trae nslookup y wget en el mismo binario y por eso sirve para los dos oficios del laboratorio. Un tag es mutable, un digest no.
- Haber leído los Capítulos 13, 14 y 15. Este laboratorio no vuelve a explicar qué es un Service, cómo se arma el nombre DNS de un Service, por qué un podSelector vacío selecciona a todos, ni por qué crear un Ingress no basta para que la entrada funcione; le hace operar las tres cosas contra un clúster real. El montaje le entrega además una avería deliberada, codificada en base64 para que usted no la lea de una ojeada. No es un escondite, es una cortesía para que usted diagnostique en vez de reconocer; la respuesta está en el campo cmd del Paso 2.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 13: El nombre fijo del local, aunque los cocineros cambien (10 pts)

El Capítulo 13 lo dijo con el domicilio: el cliente no pide que le manden el almuerzo a la mesa 4 de la cocina, porque mañana el cocinero está en la mesa 9 y el almuerzo llega frío a un puesto vacío. El cliente pide a nombre del local. Lo que pasa es que en Kubernetes el local es el Service, los cocineros son los Pods, y el que traduce el nombre del local a la lista de mesas ocupadas hoy es el plano de control, que va escribiendo esa lista en un EndpointSlice cada vez que un Pod aparece o desaparece.

En este paso usted monta la cocina central con tres cocineros, le pone su Service ClusterIP, y comprueba dos cosas que casi todo el mundo confunde en una sola.

La primera es que el EndpointSlice se llenó. Mire la columna ENDPOINTS y compárela, dirección por dirección, con las IPs que muestra kubectl get pods -o wide. Si el EndpointSlice está vacío, no importa que el Service se vea perfecto: nadie va a llegar.

La segunda es el DNS, que es cosa distinta. Levante un Pod cliente y pregúntele al DNS del clúster por el nombre completo, con las cuatro partes que el capítulo le enseñó: nombre del Service, punto, namespace, punto, svc, punto, `cluster.local`. Quédese leyendo la salida entera y no la última línea: las primeras dos líneas traen el 10.96.0.10 con el puerto pegado, y eso NO es la respuesta, es CoreDNS diciendo aquí estoy. La respuesta viene más abajo, en el bloque Name/Address.

Y resolver un nombre no es lo mismo que llegar al local. Un nombre puede resolver perfecto a una ClusterIP que no lleva a ninguna parte porque el Service se quedó sin endpoints. Por eso el último comando de este paso no es un nslookup sino un wget contra el nombre: que le conteste el HTML de nginx es la única prueba de que el domicilio llegó.

ENTREGABLE: el Deployment cocina-central con 3 réplicas listas, el Service domicilios, el Pod el-mensajero corriendo, y el archivo `~/ckad-lab/p05/01-respuesta.txt`, de 3 líneas:

```text
NOMBRE_COMPLETO=<el nombre completo, terminado en `svc.cluster.local`, que usted le preguntó al DNS>
CLUSTERIP_POR_DNS=<la dirección que el DNS devolvió para ese nombre>
ENDPOINTS_LISTOS=<cuántas direcciones listas tiene el EndpointSlice del Service>
```

<details>
<summary>Qué debería ver</summary>

El Deployment queda con 3 de 3 réplicas listas y kubectl get pods -o wide muestra sus tres direcciones. El Service domicilios aparece con TYPE en ClusterIP, una CLUSTER-IP del rango de servicios (algo del estilo 10.96.x.x) y PORT(S) en 80/TCP. El EndpointSlice aparece con las TRES direcciones en la columna ENDPOINTS, las mismas que muestran los Pods. El nslookup imprime primero las dos líneas del servidor, Server y Address con el 10.96.0.10 y el puerto pegado, que NO son la respuesta sino quién contestó, y más abajo el bloque Name/Address con el nombre completo y una única dirección, que coincide letra por letra con lo que devuelve el jsonpath de spec.clusterIP. El wget por nombre imprime las primeras líneas del HTML de bienvenida de nginx: el nombre no solo resuelve, además lleva tráfico.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 13: La heladería se cambió de sede y el pedido sigue saliendo para la sede vieja (10 pts)

El montaje del laboratorio ya le dejó puesto un segundo Service en la plazoleta, llamado domicilios-heladeria, que lleva ahí desde antes de que usted llegara y que no tiene ni un endpoint. Ni uno. El objeto EndpointSlice existe, tiene nombre, tiene edad, y por dentro está vacío. Esto no es que el Service esté roto ni que Kubernetes se haya trabado: es que alguien escribió un selector que ya no le queda a nadie. La heladería se cambió de sede y el pedido siguió saliendo para la sede vieja.

Su trabajo es diagnosticarlo con las herramientas del Capítulo 13, no adivinarlo. Ponga las dos verdades una al lado de la otra: el selector del Service por un lado, las etiquetas de la plantilla del Deployment por el otro, e identifique cuál de las dos claves no cuadra. Fíjese en que hay dos claves y solo una está peleada.

Y aquí este laboratorio le hace una advertencia que no se parece a la de otros: EN ESTE PASO CUALQUIERA DE LAS DOS REPARACIONES SE ACEPTA. En la vida real las dos reparaciones son legítimas según de quién sea el contrato: si el nombre de la sede lo manda el equipo de la aplicación, se corrige el Service; si lo manda la plataforma, se mueve el Deployment. Las dos rutas pasan. Lo único que no pasa es dejar el barrio a medias.

Lo que se le exige, y que está escrito completo en la pista de la comprobación, es que las dos partes terminen de acuerdo sobre la clave sede, con el mismo valor, y que el EndpointSlice del Service se haya llenado solo, por el plano de control, con las direcciones vivas de esos dos Pods. Borrarle la clave sede al selector para que el problema desaparezca no cuenta: eso no es reconciliar, eso es dejar de preguntar.

Y como usted es el que sabe qué hizo, el archivo de respuesta se lo pregunta de frente. La comprobación no le cree por fe: contrasta lo que usted declaró contra el valor que quedó vivo en el clúster, porque la sede que sobrevive delata cuál lado se movió.

La avería venía codificada en base64 dentro del setup a propósito. No es un escondite serio, es una cortesía para que usted diagnostique en vez de reconocer; la respuesta completa está en el campo cmd de este paso, cuando usted decida revelarlo.

ENTREGABLE: el Service domicilios-heladeria con sus 2 endpoints, el Deployment con 2 réplicas listas, y el archivo `~/ckad-lab/p05/02-respuesta.txt`, de 3 líneas:

```text
SEDE_ACORDADA=<el valor de la clave sede en el que quedaron de acuerdo el Service y el Deployment>
LADO_QUE_CAMBIE=<servicio, deployment o ambos, según cuál lado movió usted>
ENDPOINTS_HELADERIA=<cuántas direcciones listas tiene el EndpointSlice del Service al final>
```

<details>
<summary>Qué debería ver</summary>

Antes de tocar nada, kubectl get svc muestra el Service domicilios-heladeria con su CLUSTER-IP normal, como si estuviera perfecto, y el EndpointSlice aparece con ENDPOINTS en <unset>, es decir vacío, aunque el objeto EndpointSlice sí existe y tiene edad. Los Pods de la heladería aparecen Running, con sus etiquetas visibles gracias a --show-labels. Al imprimir los dos jsonpath se ve el choque: el selector del Service dice sede sur y las etiquetas de la plantilla del Deployment dicen sede norte, mientras que la clave app coincide en los dos. Después del patch, el mismo EndpointSlice de siempre, con el mismo nombre y la misma edad, se llena con las dos direcciones de los Pods: no se creó uno nuevo, se actualizó el que estaba.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 15: Primero mida que el local le habla a cualquiera, y solo después ponga la regla (10 pts)

El Capítulo 15 terminó con la advertencia más importante de esta parte: un NetworkPolicy es apenas un pedazo de texto guardado en la API, y si el CNI del clúster no sabe leerlo, usted puede aplicar la política más elegante del mundo, verla listada con kubectl get, y que el tráfico siga pasando igualito. El celador de mentiras.

Por eso este clúster no se creó como los demás. Se creó con disableDefaultCNI en true y con Calico instalado encima, a propósito, y el setup no se conformó con instalarlo: levantó un namespace de prueba desechable, midió que un Pod le hablaba a otro, aplicó una negación total, volvió a medir, y solo le entregó el laboratorio cuando comprobó que el segundo intento fallaba. Si esa medición no hubiera pasado, el setup habría muerto con un error con nombre en vez de dejarlo a usted haciendo un paso decorativo.

Y por eso el orden de este paso no se puede invertir. Primero MIDA. Antes de aplicar nada, haga los dos wget y vea con sus propios ojos que los dos salen con código 0: la galería no tiene chapas, cualquiera entra a cualquier local. Esa línea base no es un trámite, es la única manera de saber después que lo que cambió fue la política y no otra cosa.

Después ponga la regla, y póngala en dos piezas, que es como se hace en la práctica. La primera es la negación por defecto: podSelector vacío, o sea TODOS los Pods del namespace, policyTypes con Ingress, y ninguna regla adentro. Acuérdese de lo que dijo el capítulo: un podSelector vacío no selecciona a nadie, selecciona a todo el mundo. La segunda es la que abre una sola puerta: aplica a los Pods con rol=local y deja entrar únicamente a los que traigan la etiqueta acceso=permitido, y solo por el puerto 80.

Y ahora repita la medición. El mensajero con carnet entra como si nada. El vendedor ambulante se queda parado cinco segundos completos y se rinde. Fíjese en ese detalle porque el examen lo pregunta de mil formas: no le contestan que no, sencillamente no le contestan. Un paquete bloqueado por política de red no rebota, se pierde, y por eso lo que usted ve es un tiempo agotado y no un connection refused.

Última advertencia, y esta es seria: si a usted se le ocurre ponerle el carnet al vendedor ambulante para que el síntoma desaparezca, el tráfico va a pasar y el paso va a fallar. Está dicho de frente en la pista de la comprobación.

ENTREGABLE: los tres Pods corriendo en la-galeria con sus etiquetas, las dos NetworkPolicies aplicadas, y el archivo `~/ckad-lab/p05/03-respuesta.txt`, de 2 líneas:

```text
SALIDA_CON_CARNET=<el código de salida del wget del mensajero con carnet DESPUÉS de aplicar las políticas>
SALIDA_SIN_CARNET=<el código de salida del wget del vendedor ambulante DESPUÉS de aplicar las políticas>
```

<details>
<summary>Qué debería ver</summary>

En la línea base los dos wget devuelven código de salida 0: la galería está abierta y cualquier Pod le habla a cualquier otro, tal como dice el modelo de red de Kubernetes. Después de aplicar las dos políticas, el wget del mensajero con carnet sigue devolviendo 0, y el del vendedor ambulante se queda callado cinco segundos completos y devuelve 1, que es como se ve un tiempo agotado y no un rechazo: nadie le contesta que no, sencillamente no le contesta. kubectl get networkpolicies lista las dos políticas, y la de negación por defecto aparece con POD-SELECTOR en <none>, que es como kubectl muestra el selector vacío que selecciona a todos.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 14: El directorio de la entrada manda a cada quien a su local (10 pts)

El Capítulo 14 insistió en una sola cosa: el directorio puede estar perfectamente atornillado a la pared de la entrada, pero si nadie contrató a la empresa que atiende esa entrada, el letrero no lleva a nadie a ninguna parte. Crear un Ingress no tiene ningún efecto sin un Ingress controller que lo atienda.

En este clúster la empresa ya está contratada: el setup instaló ingress-nginx, y aquí toca decir la verdad completa, la misma que dicen los prerrequisitos. Ese proyecto fue retirado y su repositorio quedó archivado en solo lectura. La versión que usted tiene instalada, controller-v1.15.1, publicada el 2026-03-19, es la última que existirá: no habrá más parches, ni siquiera de seguridad. La entrada funciona, pero la empresa que le hacía mantenimiento cerró. Se lo decimos porque un desarrollador que propone un controlador sin saber eso está tomando una decisión con la mitad de la información.

Su trabajo es el directorio. Monte dos locales, cada uno su Deployment y su Service, cada uno sirviendo un texto distinto para que después no haya duda de cuál contestó. Después escriba UN Ingress con dos rutas, /ropa y /helados, cada una apuntando al Service que le corresponde.

Y no se salte ingressClassName. El Capítulo 14 explicó para qué existe: un mismo clúster puede tener varios controladores instalados, y ese campo es el que dice, sin ambigüedad, cuál de ellos atiende esta lista de reglas. Antes de escribirlo, mire con kubectl get ingressclass cuál hay disponible y confirme con jsonpath cuál controlador la respalda, en vez de escribir nginx de memoria.

Para entrar desde afuera use curl contra el puerto 8085 del host, que el setup mapeó al puerto 80 del nodo, y mande el encabezado Host que la regla espera. Eso es lo que hace un navegador cuando alguien escribe el dominio, solo que sin necesitar DNS. Y no se salte el tercer curl, con un host que no existe en ninguna regla: el código que le devuelva es una de las tres líneas que hay que entregar, y no se puede adivinar sin hacerlo.

Una advertencia de ritmo: el controlador no recarga sus reglas en el mismo instante del apply. Si usted hace curl de una, le contesta 404 y parece que el Ingress no sirviera. Por eso el comando de este paso reintenta de forma acotada antes de dar el resultado por bueno, y la comprobación hace lo mismo.

ENTREGABLE: los dos Deployments con sus Services en el-centro-comercial, el Ingress directorio-de-la-entrada con las dos rutas, y el archivo `~/ckad-lab/p05/04-respuesta.txt`, de 3 líneas:

```text
CLASE_DEL_DIRECTORIO=<el valor de spec.ingressClassName que usted le puso al Ingress>
HOST_DEL_DIRECTORIO=<el host que declaró la regla del Ingress>
HTTP_HOST_DESCONOCIDO=<el código HTTP que devolvió el curl con un host que no está en ninguna regla>
```

<details>
<summary>Qué debería ver</summary>

kubectl get ingressclass lista la clase nginx, y el jsonpath imprime k8s.io/ingress-nginx, que es el nombre del controlador que la atiende. El Ingress queda listado con CLASS en nginx, HOSTS en centrocomercial.local y PORTS en 80. El describe muestra las dos rutas con sus backends y, debajo de cada una, las direcciones de los Pods de atrás, no solo el nombre del Service. El primer curl imprime LOCAL DE ROPA y el segundo imprime LOCAL DE HELADOS, cada uno saliendo del Service correcto. El tercer curl, con un host que no aparece en ninguna regla, devuelve HTTP 404: el directorio existe, pero ese centro comercial no está en la lista.

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

- **Síntoma (step 1):** nslookup contesta NXDOMAIN o server can't find
  **Qué hacer:** Casi siempre es el nombre, no el DNS. Confirme que escribió las cuatro partes: `servicio.namespace.svc.cluster.local`. Un Pod que vive en otro namespace no puede preguntar solo por el nombre corto, tiene que dar por lo menos servicio.namespace. Si el nombre completo tampoco resuelve, revise que los Pods de CoreDNS estén Running con $K -n kube-system get pods -l k8s-app=kube-dns.

- **Síntoma (step 1):** El nslookup devuelve una dirección pero el wget se queda colgado
  **Qué hacer:** Ese es justo el caso que este paso le quiere enseñar: el nombre resuelve y el destino no contesta. Mire el EndpointSlice del Service; si la columna ENDPOINTS aparece en <unset>, el Service no tiene a quien mandarle el tráfico y el nombre resuelve a una ClusterIP hueca. Revise que el selector del Service coincida con las etiquetas de la plantilla del Deployment y que los Pods estén Running.

- **Síntoma (step 1):** wget: unrecognized option: -T
  **Qué hacer:** Ese error significa que el wget que corrió no es el de busybox. Confirme que el Pod cliente se creó con la imagen busybox fijada por digest de este paso y no con otra que usted tuviera a la mano. Si prefiere otra imagen, use su equivalente de tiempo de espera, pero deje un tiempo acotado: sin el, el wget se cuelga y usted nunca ve el código de salida.

- **Síntoma (step 2):** kubectl get endpointslices no devuelve nada para domicilios-heladeria
  **Qué hacer:** Revise que esté consultando el namespace la-plazoleta y que la etiqueta del filtro sea kubernetes.io/service-name=domicilios-heladeria. Ese es el nombre de etiqueta que el plano de control le pone a cada EndpointSlice para amarrarlo a su Service; escrito de cualquier otra forma, el filtro no encuentra nada y usted concluye que no existe cuando si existe.

- **Síntoma (step 2):** El patch falla con un error que dice que la ruta no existe
  **Qué hacer:** Un patch de tipo json con la operación replace exige que la ruta ya exista. Si usted ya borró la clave sede, la operación correcta es add en vez de replace, o más fácil, edite el objeto con kubectl edit y déjelo como debe quedar. La comprobación califica el estado final, no el comando que usted usó para llegar.

- **Síntoma (step 2):** Moví el Deployment y ahora la comprobación falla con 2 réplicas listas
  **Qué hacer:** Cambiar una etiqueta de la plantilla dispara un despliegue nuevo: durante unos segundos conviven Pods de la revisión vieja y de la nueva, y el conjunto de direcciones del EndpointSlice no cuadra con el de los Pods de la sede nueva. Espere a que termine con $K -n la-plazoleta rollout status deploy/heladeria-la-nieve, deje pasar unos segundos más para que el EndpointSlice se ponga al día, y vuelva a calificar. Ojo: la clave app NO se puede mover, porque vive también en spec.selector.matchLabels del Deployment y ese campo es inmutable.

- **Síntoma (step 3):** Después de aplicar las políticas, el vendedor ambulante sigue entrando con código 0
  **Qué hacer:** Ese es el síntoma del celador de mentiras, y lo primero que hay que descartar es el CNI. Confirme que Calico quedó vivo con $K get tigerastatus y que los Pods de calico-system están Running; si el clúster se creó sin disableDefaultCNI, o si Calico nunca terminó de instalarse, las políticas quedan guardadas en la API y no las aplica nadie. Lo segundo que hay que revisar es que las dos políticas estén en el namespace la-galeria y no en default: un NetworkPolicy solo actúa dentro de su propio namespace. Y lo tercero, deje pasar unos segundos: el CNI no programa las reglas en el mismo instante del apply.

- **Síntoma (step 3):** Ahora el mensajero con carnet tampoco entra
  **Qué hacer:** Revise la política que abre la puerta, en este orden. Que su podSelector apunte a rol=local, que es la etiqueta del local de jugos y no la del cliente. Que la regla ingress traiga from con un podSelector que diga acceso=permitido. Y que el puerto declarado sea el 80 TCP, que es donde escucha nginx: una regla que abre el puerto equivocado se ve perfecta en el YAML y bloquea igual que si no existiera.

- **Síntoma (step 3):** El wget del vendedor ambulante se queda colgado y nunca vuelve
  **Qué hacer:** Le faltó el tiempo de espera. Un paquete bloqueado por NetworkPolicy no rebota, se pierde, así que sin -T el wget espera el tiempo por defecto del sistema y usted se queda mirando la terminal. Use -T 5 como en el comando de este paso; ese número acotado es lo que convierte el bloqueo en un código de salida que se puede medir.

- **Síntoma (step 4):** curl devuelve 404 en las dos rutas
  **Qué hacer:** Revise cuatro cosas en este orden. Que le haya dado tiempo al controlador de recargar: espere unos segundos y repita, porque el apply no es instantáneo. Que esté mandando el encabezado Host y que coincida letra por letra con el host de la regla: sin ese encabezado, el controlador no encuentra ninguna regla que aplicar. Que esté pidiendo /ropa/ con la barra final, porque el contenido vive en un subdirectorio y nginx responde 301 hacia la barra si usted la omite. Y que el describe del Ingress muestre direcciones de Pods debajo de cada backend: si aparece vacío, el problema no es la entrada sino que el Service de atrás se quedó sin endpoints.

- **Síntoma (step 4):** curl no conecta con localhost:8085
  **Qué hacer:** Ese puerto solo existe porque el clúster se creó con extraPortMappings. Confirme con docker port ckad-p05-control-plane que el 8085 del host está mapeado al 80 del nodo; si no aparece, el clúster se creó sin el archivo kind-p05.yaml y hay que rehacerlo, porque extraPortMappings no se puede agregar a un clúster ya creado.

- **Síntoma (step 4):** kubectl apply del Ingress falla con un error del webhook de admisión
  **Qué hacer:** ingress-nginx instala un ValidatingWebhookConfiguration que revisa cada Ingress antes de aceptarlo. Si el controlador todavía no terminó de arrancar, ese webhook no responde y el apply falla. Espere a que el Pod del controlador esté listo con $K wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s y vuelva a aplicar.

## Para ir más lejos

- Cree un Service headless en la-plazoleta, con clusterIP en None y el mismo selector de cocina-central, y vuelva a hacer el nslookup desde el-mensajero. Cuente los registros que devuelve. Después escale el Deployment a 5 réplicas y repita. Sin tocar el DNS ni el Service, el número de respuestas cambia solo, y eso le muestra de dónde sale la lista que contesta CoreDNS.
- Borre la clave sede del selector de domicilios-heladeria en vez de reconciliar el valor, y observe que el Service se llena de endpoints igual. Después explique con sus propias palabras por qué un selector con menos claves selecciona MÁS Pods, no menos, y qué pasaría si otro Deployment del mismo namespace también llevara la etiqueta app=heladeria-la-nieve.
- Agregue una tercera política de egreso en la-galeria que impida al mensajero con carnet salir a cualquier lado excepto al DNS del clúster, y compruebe que ahora el wget por nombre falla mientras el wget por IP sigue pasando. Es un error de producción con NetworkPolicy: cerrar el egreso y olvidarse de abrir el puerto 53.
- Agregue una segunda regla de host al mismo Ingress, con otro host y una sola ruta, y compruebe con curl que el mismo controlador atiende los dos dominios sin que usted haya instalado nada nuevo. Eso es el hospedaje virtual basado en nombre del que habla la documentación oficial, en un solo objeto.

## Referencias

- Kubernetes Project, Service. The authority on ClusterIP as the default type and on the selector that binds a Service to its Pods, the basis for Steps 1 and 2. https://kubernetes.io/docs/concepts/services-networking/service/
- Kubernetes Project, EndpointSlices. States that the control plane automatically creates EndpointSlices for any Service that has a selector and keeps them updated as the Pod set changes, and documents the kubernetes.io/service-name label used to filter them and the endpointslice.kubernetes.io/managed-by label the checks read. https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- Kubernetes Project, DNS for Services and Pods. Documents the service.namespace.svc.cluster.local form queried in Step 1. https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- Kubernetes Project, Connecting Applications with Services. Walks the same path this lab's Step 1 walks: expose a Deployment, confirm the endpoints, then reach it by DNS name from another Pod. https://kubernetes.io/docs/tutorials/services/connect-applications-service/
- Kubernetes Project, Network Policies. Documents podSelector, policyTypes and the ingress rule list, states that an empty podSelector selects all Pods in the namespace, and warns that network policies are implemented by the network plugin and that creating the resource without a controller that implements it has no effect, which is the entire justification for this lab's CNI choice and for the setup's substrate probe. https://kubernetes.io/docs/concepts/services-networking/network-policies/
- Kubernetes Project, Cluster Networking. States the model this lab measures as its Step 3 baseline: all Pods can communicate with all other Pods without NAT. https://kubernetes.io/docs/concepts/services-networking/
- Project Calico, release v3.32.1. The pinned CNI release used by this lab's setup, verified 2026-08-21 as the newest release of the v3.32 line. https://github.com/projectcalico/calico/releases/tag/v3.32.1
- Project Calico, Installation API reference. Documents the operator.tigera.io/v1 Installation resource and its calicoNetwork.ipPools fields, which this lab writes by hand instead of using the published custom-resources.yaml so the pool does not land on 192.168.0.0/16. https://docs.tigera.io/calico/latest/reference/installation/api
- Kubernetes Project, Ingress. Defines the Ingress resource, the host, path, pathType and backend fields used in Step 4, and states that ingressClassName selects which controller serves the rules. https://kubernetes.io/docs/concepts/services-networking/ingress/
- Kubernetes Project, Ingress Controllers. States as its first prerequisite that you must have an Ingress controller to satisfy an Ingress and that creating the resource alone has no effect, the point Step 4 makes readers prove. https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- kubernetes/ingress-nginx, release controller-v1.15.1 (2026-03-19). The final release of the project, and the source of the kind provider manifest this lab pins; the repository itself is archived read-only, verified against the GitHub API on 2026-08-21. https://github.com/kubernetes/ingress-nginx/releases/tag/controller-v1.15.1
- kind Project, Configuration. Documents networking.disableDefaultCNI, networking.podSubnet and nodes[].extraPortMappings, the three settings this lab's cluster configuration depends on. https://kind.sigs.k8s.io/docs/user/configuration/
- kind Project, release v0.32.0. The source of the digest-pinned kindest/node:v1.36.1 image and of the instruction to pin node images by @sha256 rather than by tag. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
