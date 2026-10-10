# Parte IV - Laboratorio: un puesto que no cabía en la plaza y hubo que medirlo, un menú que se lee y una caja fuerte que no se copia, un empleado de uniforme que igual trabaja, y un carné que abre una puerta y ninguna más

- Tiempo: 55 min
- Puntos: 40

## Objetivo

Este es un laboratorio Exam-Style: cada paso le dice solo el objetivo y el entregable, y la secuencia de comandos que lo resuelve vive en el campo cmd de ese paso para que usted la revele después de haberlo intentado con sus propias manos. El Paso 1 le entrega un manifiesto de Pod que el API server rechaza en la cara, porque la administración de la plaza le puso a ese namespace un ResourceQuota, y le pide que lo haga arrancar midiendo bien lo que el puesto pide y lo que se le deja usar; la calificación exige que el Pod quede corriendo y que el cupo siga intacto, así que borrar la cuota o aflojarla es la forma más rápida de perder el paso. El Paso 2 monta el negocio del Capítulo 10: usted crea el menú del día como ConfigMap y consume ese menú y la clave de la caja fuerte que ya existe, las dos cosas a la vez como variables de entorno y como archivos montados, y la calificación entra al contenedor vivo a leer los valores montados y además revisa que la clave entre por referencia y no escrita a mano en el manifiesto. El Paso 3 le pone el uniforme obligatorio del Capítulo 12: un Pod endurecido que no corre como root, que tiene la raíz en solo lectura y que renuncia a todas las capabilities, y que aun así sigue trabajando; la calificación lee los campos declarados y después le pregunta al proceso vivo quién es y qué puede hacer. El Paso 4 cierra con el carné: una ServiceAccount propia, con un Role y un RoleBinding que le dan los verbos que la aplicación necesita y ni uno más, comprobado con kubectl auth can-i por los dos lados y ejercitado desde adentro del Pod contra el API server; darle cluster-admin al carné hace fallar el paso, que es justo lo que tenía que pasar.

## Prerrequisitos

- Una máquina Linux con kind, kubectl y docker en el PATH, acceso a internet, y al menos 4 GB de RAM libre. Este laboratorio crea su propio clúster de kind llamado ckad-p04, de un solo nodo, y lo borra al final. Todo lo que hace pasa por un kubeconfig privado en ~/ckad-lab/p04/kubeconfig, que se pasa con --kubeconfig en cada comando: su kubeconfig de siempre nunca se toca, su contexto actual nunca cambia, y ningún otro clúster suyo se ve afectado. No ejecute este laboratorio contra un clúster de producción.
- Versiones fijadas y verificadas el 2026-10-09 en la máquina donde se ejecutó este laboratorio: kind v0.33.0, kubectl v1.37.0, imagen de nodo kindest/node:v1.36.1 fijada por digest sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, y la imagen de carga de trabajo busybox:1.37.0 fijada por digest sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirme su kind con kind version y su kubectl con kubectl version --client antes de empezar, en vez de creerle a este párrafo.
- El script de setup no se limita a construir el clúster: le hace tres pruebas antes de dejarlo empezar, porque los cuatro pasos dan por hecho tres comportamientos que un clúster puede aceptar por API y no aplicar en la práctica. Comprueba que el ResourceQuota rechace un Pod sin medidas, que el modo de autorización RBAC diga que no cuando debe, y que runAsNonRoot impida arrancar una imagen que corre como root. Si alguna falla, el setup imprime un error con nombre propio y se detiene, porque un laboratorio que califica un control que nadie aplica es decoración.
- Todos los pasos trabajan dentro del namespace plaza y ese namespace tiene un ResourceQuota puesto por el setup. Eso quiere decir que cada Pod que usted cree en este laboratorio, no solo el del Paso 1, tiene que declarar requests y limits de CPU y de memoria, o el API server se lo rechaza. No es un capricho del enunciado: es el efecto real de tener una cuota de cómputo en un namespace, y las cuatro comprobaciones vuelven a leer el cupo para confirmar que sigue como estaba.
- Haber leído los Capítulos 9, 10, 11 y 12. Este laboratorio no vuelve a explicar qué es un request, qué diferencia hay entre un ConfigMap y un Secret, qué es un CustomResourceDefinition ni qué hace un RoleBinding; le hace operar las cuatro cosas contra un clúster real y las califica contra su estado real.

## Pasos

El `0N-step.sh` está para que no se quede atascado: lea el paso, intente primero por su cuenta y corra el script cuando quiera comparar. Escribe también el archivo de respuesta que el paso pide, leyendo los valores del clúster vivo.

### 1. Cap. 9: El puesto no cabía en la plaza, y la plaza no se va a agrandar (10 pts)

El Capítulo 9 le explicó que en la plaza de mercado cada puesto ocupa un pedazo, y que la administración lleva la cuenta del total. Aquí le toca vivirlo desde el lado incómodo: alguien le dejó un manifiesto listo para aplicar, usted lo aplica confiado, y el API server se lo devuelve en la cara.

Lo que pasa es que ese rechazo no es un error suyo de sintaxis ni un problema del clúster. Es el ResourceQuota del namespace plaza haciendo lo que le pidieron. Y el mensaje que le devuelve es de los más generosos que da Kubernetes, porque le entrega las tres cifras completas: requested (lo que usted pidió), used (lo que ya estaba ocupado) y limited (el techo del namespace). Con esas tres, el ejercicio de medir el puesto es aritmética de tienda, no adivinanza.

Y ojo con una cosa que en el examen se paga carísimo: cuando un namespace tiene una cuota sobre recursos de cómputo, todo Pod que entre ahí tiene que declarar requests y limits de CPU y de memoria. No es opcional, no es buena práctica, es admisión. Si a usted se le olvida un solo campo, el error ya no dice exceeded quota sino must specify limits.cpu, y mucha gente pierde diez minutos buscando dónde se pasó de tamaño cuando lo que faltaba era un campo.

Y aquí viene la que más duele: la salida fácil no es agrandar la plaza. Borrar la cuota, subirle el número o poner otra cuota más ancha al lado hace que el Pod arranque en tres segundos y hace que usted repruebe, porque el puesto entra pero la plaza dejó de tener administración. En un clúster real esa es la diferencia entre un equipo que se quedó sin memoria y un nodo entero que se cayó por culpa suya. Tampoco vale desalojar al vecino: el puesto de jugos que ya estaba ahí no es suyo, y sacarlo para hacerse espacio es la versión con más pasos del mismo atajo.

ENTREGABLE: el Pod `puesto-de-frutas` corriendo en el namespace plaza, el `puesto-de-jugos` intacto, el ResourceQuota `cupo-de-la-plaza` tal como lo dejó el setup, y el archivo `~/ckad-lab/p04/01-respuesta.txt`, de 2 líneas:

```text
CUPO_DE_MEMORIA_PEDIDA=<el techo de requests.memory que declara el ResourceQuota>
MEMORIA_PEDIDA_POR_EL_PUESTO=<el requests.memory que su contenedor de puesto-de-frutas declara, escrito tal cual lo devuelve el clúster>
```

<details>
<summary>Qué debería ver</summary>

El primer apply se estrella y el error dice qué pasó: pods "puesto-de-frutas" is forbidden: exceeded quota: cupo-de-la-plaza, requested: limits.cpu=2,limits.memory=2Gi,requests.cpu=1,requests.memory=1Gi, used: limits.cpu=800m,limits.memory=800Mi,requests.cpu=400m,requests.memory=400Mi, limited: limits.cpu=2,limits.memory=2Gi,requests.cpu=1,requests.memory=1Gi. Fíjese en que el mensaje trae las tres cifras que importan: lo que usted pidió, lo que ya estaba ocupado por el puesto de jugos, y el techo del namespace. Con el manifiesto medido, el segundo apply crea el Pod, el wait devuelve pod/puesto-de-frutas condition met, y el listado muestra los dos puestos en Running. Las tres últimas líneas imprimen cupo_pedido_memoria=1Gi y, en la máquina donde se ejecutó este laboratorio, en_uso_memoria=528Mi y memoria_pedida_por_el_puesto=128Mi. Los 528Mi son los 400Mi del puesto de jugos más los 128Mi que usted acaba de pedir; esa cifra intermedia va a seguir subiendo a medida que usted cree los Pods de los Pasos 2, 3 y 4, así que no es la que se anota. La primera y la tercera sí son estables: el techo es del cupo y la tercera es la medida que usted eligió.

</details>

```bash
./01-step.sh
./01-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 2. Cap. 10: El menú se lee en voz alta, la clave de la caja no se copia en ningún papel (10 pts)

El Capítulo 10 le mostró los dos tableros que tiene todo negocio: el menú del día, que está colgado a la vista de todo el mundo y cambia cuando el dueño quiera, y la caja fuerte detrás del mostrador, que también se abre, pero no delante de los clientes. ConfigMap y Secret son eso, y en Kubernetes se consumen igual: como variables de entorno o como archivos montados.

Lo que pasa es que la gente aprende una sola de las dos formas y después se pierde el día del examen. Como variable de entorno, el valor se le entrega al proceso cuando el contenedor arranca, y se queda congelado ahí hasta que el Pod se recree. Como archivo montado, cada llave se convierte en un archivo con el nombre de la llave, y el kubelet lo va refrescando cuando el objeto cambia. Por eso este paso le pide las dos: para que vea con sus propios ojos que el mismo dato llega por dos caminos distintos y que ninguno de los dos es "el correcto".

Sobre el Secret hay que decir la verdad completa, porque medio mundo la dice a medias: base64 no es cifrado. Es codificación, y se deshace con un comando. Un Secret no protege el valor de quien pueda leer el objeto; lo que hace es sacarlo del manifiesto, sacarlo del repositorio de código, y ponerlo detrás de un permiso de RBAC que se puede negar. Esa negación es precisamente lo que usted va a construir en el Paso 4.

Y aquí está el error que este paso califica en serio: escribir la clave a mano en el manifiesto. Poner env con name CLAVE_DE_LA_CAJA y value con la clave escrita ahí produce el mismo printenv, se ve igual de bien en la demostración, y es justo lo que el Secret existía para evitar; ese manifiesto se va al repositorio con la clave adentro. Lo mismo con montar un emptyDir y escribir el archivo al arrancar. La calificación mira de dónde viene el dato, no cómo se ve.

ENTREGABLE: el ConfigMap `menu-del-dia` con las llaves `plato-del-dia` valiendo ajiaco-santafereno y `postre-del-dia` valiendo brevas-con-arequipe, y el Pod `cocinero` corriendo en el namespace plaza que consuma el ConfigMap y el Secret `caja-fuerte` por las dos vías: la variable `PLATO_DEL_DIA` desde el ConfigMap, la variable `CLAVE_DE_LA_CAJA` desde el Secret, el ConfigMap montado en `/etc/menu` y el Secret montado en /etc/caja. Además el archivo `~/ckad-lab/p04/02-respuesta.txt`, de 3 líneas:

```text
PLATO_MONTADO=<el contenido del archivo del plato, leído dentro del contenedor>
CLAVE_LARGO=<cuántos caracteres tiene la clave, contados dentro del contenedor>
ORIGEN_DE_LA_CLAVE=<el nombre exacto del campo de valueFrom que usó para traer la clave del Secret>
```

<details>
<summary>Qué debería ver</summary>

La consulta al Secret imprime tipo=Opaque y una lista de llaves donde el valor ya viene en base64, que es codificación y no cifrado: cualquiera que pueda leer el Secret puede leer la clave, y por eso el permiso de leer Secrets se reparte con cuentagotas en el Paso 4. El Pod arranca sin drama y el ls muestra el archivo clave dentro de /etc/caja y los dos archivos plato-del-dia y postre-del-dia dentro de `/etc/menu`, con el nombre de cada llave convertido en nombre de archivo. El cat y el printenv imprimen los dos ajiaco-santafereno, que es la prueba de que el mismo dato llegó por los dos caminos, montado y por variable de entorno; en la terminal los va a ver pegados en una sola línea, ajiaco-santaferenoajiaco-santafereno, porque el archivo montado no trae salto de línea al final y el valor termina justo donde empieza el siguiente. El wc -c sobre el archivo montado del secreto devuelve 30 en la máquina donde se ejecutó este laboratorio, sin ningún salto de línea al final: un Secret montado no le agrega nada al valor.

</details>

```bash
./02-step.sh
./02-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 3. Cap. 12: El uniforme es obligatorio, y con uniforme también se trabaja (10 pts)

El Capítulo 12 le habló del uniforme obligatorio: en el negocio nadie entra a la cocina de particular, y no es por moda. El securityContext es el uniforme del Pod, y este paso le pide ponerle el completo a un contenedor que igual tiene que seguir trabajando, que es la parte difícil.

Lo que pasa es que las tres piezas del uniforme atacan tres cosas distintas y la gente las mezcla. runAsNonRoot es una promesa que el kubelet verifica antes de arrancar: si la imagen iba a correr como root, el contenedor no arranca y usted ve CreateContainerConfigError con el mensaje literal image will run as root. runAsUser es el número concreto del empleado, y sin él una imagen que no declara un usuario propio no tiene cómo cumplir la promesa. readOnlyRootFilesystem monta el sistema de archivos del contenedor en solo lectura, o sea que quien se meta ahí no puede dejar nada escrito. Y capabilities.drop con ALL le quita al proceso todos los superpoderes parciales de root, esos que uno olvida que existen hasta que alguien los usa.

Aquí está lo que hace útil este paso y no solo estricto: el contenedor tiene que seguir escribiendo su latido. Un uniforme que impide trabajar no lo usa nadie, y en producción el equipo lo quita al tercer incidente. La respuesta es la de siempre en Kubernetes: si el proceso necesita escribir, se le da un volumen escribible en la ruta exacta donde escribe, y la raíz se queda en solo lectura. Eso es endurecer bien, y es distinto de endurecer hasta romper.

Y aquí va una confusión que conviene evitar: dejar el drop ALL y añadir de vuelta una capability con capabilities.add "por si acaso". El manifiesto se ve endurecido, la revisión de código pasa, y el conjunto acotado del proceso ya no está vacío. Esta calificación lee CapBnd además de CapEff justamente por eso, así que ese "por si acaso" se ve.

ENTREGABLE: el Pod `uniformado` corriendo y Ready en el namespace plaza, que no corra como root, con la raíz en solo lectura, sin ninguna capability, sin permitir escalar privilegios, y que aun así esté escribiendo un latido reciente en `/var/latidos/pulso.txt`. Además el archivo `~/ckad-lab/p04/03-respuesta.txt`, de 3 líneas:

```text
UID_DEL_PROCESO=<el uid que el proceso reporta desde adentro del contenedor>
CAPEFF=<el valor de CapEff que el proceso reporta en /proc/self/status>
RAIZ_ESCRIBIBLE=<responda si o no, en minúscula, según lo que le pase al intentar escribir en /tmp desde adentro>
```

<details>
<summary>Qué debería ver</summary>

El Pod queda Ready sin reintentos. El id imprime uid=1000 gid=3000 groups=3000, que no es lo que la imagen de busybox trae por defecto (root), sino lo que usted le impuso. Las tres líneas de capabilities imprimen CapPrm, CapEff y CapBnd los tres en 0000000000000000: el proceso no solo no está usando privilegios, es que no le queda ninguno ni en el conjunto acotado, así que no hay nada que recuperar. El intento de escribir en /tmp devuelve sh: can't create /tmp/prueba.txt: Read-only file system y el código de salida es 1, porque /tmp es parte de la raíz y la raíz está en solo lectura; ese detalle importa, porque un uid sin permisos no podría escribir en / de todos modos, pero en /tmp sí podría si la raíz fuera escribible. Y aun con todo el uniforme puesto, el último comando imprime dos números casi iguales, el latido escrito por el contenedor dentro del volumen emptyDir y la hora actual: readOnlyRootFilesystem nunca quiso decir que el proceso no pueda escribir en ninguna parte.

</details>

```bash
./03-step.sh
./03-check.sh
```

El verificador imprime `ok` y sale con 0 cuando el paso quedó bien, y sale con 1 cuando no. No le cree su palabra: vuelve a consultar el clúster en vivo.

### 4. Cap. 11 y 12: Un carné que abre la puerta del menú y de los pedidos, y ninguna otra (10 pts)

El Capítulo 11 le contó que a veces el barrio necesita un servicio que no existía, y que en Kubernetes eso se resuelve inventando el formulario: un CustomResourceDefinition añade un tipo nuevo al API server, y desde ese momento kubectl lo trata como a cualquier otro. En este clúster el setup ya dejó registrado el tipo Pedido, del grupo plaza.example.com, y dejó un pedido de la mesa 4. El Capítulo 12 le contó lo otro: que dentro del clúster las aplicaciones también tienen identidad, y que esa identidad es la ServiceAccount.

Lo que pasa es que es fácil descubrir las ServiceAccounts recién el día en que una aplicación empieza a fallar con 403 y busca en internet cómo arreglarlo. La primera respuesta que encuentra es darle cluster-admin, funciona de una, y así es como un contenedor comprometido termina pudiendo leer todos los Secrets del clúster. Este paso está construido para que esa salida no funcione.

El modelo son tres piezas y hay que tenerlas separadas en la cabeza. La ServiceAccount es el carné: dice quién es, no dice qué puede. El Role es la lista de lo que se puede hacer, y como es un objeto de namespace, lo que dice solo aplica dentro de ese namespace. El RoleBinding es el acto de entregarle ese permiso a ese carné, y sin él el Role es un papel bonito que no abre nada. Y cuando la aplicación necesita un recurso que usted mismo inventó con un CRD, ese recurso se nombra en el Role igual que cualquier otro, con su apiGroup propio.

La herramienta que le va a salvar el examen es kubectl auth can-i con --as. Le deja preguntarle al API server, sin desplegar nada, si una identidad concreta puede hacer una acción concreta. Úsela por los dos lados siempre: pregunte por lo que tiene que poder y pregunte por lo que no tiene que poder. Un permiso que solo se probó por el lado positivo no está probado, está supuesto.

Y viene la tentación de siempre: cluster-admin no es una solución rápida, es la renuncia al modelo entero. Y si le tienta pensar que este laboratorio exagera, mire el 403 del Secret desde adentro del Pod y piense en cuántos contenedores de su trabajo podrían hacer esa misma llamada y recibir un 200.

ENTREGABLE: la ServiceAccount `carnet-del-mesero` en el namespace plaza, un Role y un RoleBinding en ese namespace que le den get y list sobre configmaps y sobre pedidos.plaza.example.com y nada más, y el Pod `mesero` corriendo con ese carné puesto. Además el archivo `~/ckad-lab/p04/04-respuesta.txt`, de 5 líneas:

```text
CUENTA_DEL_MESERO=<el nombre de la ServiceAccount que el Pod mesero declara>
PUEDE_LEER_EL_MENU=<lo que responde kubectl auth can-i get configmaps para ese carné>
PUEDE_BORRAR_EL_MENU=<lo que responde kubectl auth can-i delete configmaps para ese carné>
PUEDE_LEER_LOS_PEDIDOS=<lo que responde kubectl auth can-i get pedidos.plaza.example.com para ese carné>
CODIGO_EN_LA_CAJA=<el código HTTP que devuelve el API server cuando el Pod mesero pide el Secret caja-fuerte con su token>
```

<details>
<summary>Qué debería ver</summary>

La consulta al CRD imprime grupo=plaza.example.com, plural=pedidos y alcance=Namespaced, y el get pedidos lista pedido-de-la-mesa-4: ese recurso no existía en el barrio y ahora se consulta con kubectl igual que un Pod, que es todo el punto del Capítulo 11. Las siete preguntas de auth can-i responden, en orden, yes, yes, no, no, yes, no y no. Fíjese en el patrón: el carné lee el menú y lee los pedidos, y no borra ninguno de los dos, no abre la caja fuerte, y no puede hacer todo en todos los namespaces. Desde adentro del Pod, el namespace del carné imprime plaza, y las tres llamadas al API server con el token proyectado devuelven HTTP/1.1 200 para el ConfigMap, HTTP/1.1 200 para la lista de pedidos, y HTTP/1.1 403 para el Secret. Ese 403 es la parte importante: no es que el mesero no encuentre la caja fuerte, es que el API server sabe quién está preguntando y le dice que no.

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

- **Síntoma (step 1):** El error no dice exceeded quota, dice must specify limits.cpu, limits.memory, requests.cpu, requests.memory
  **Qué hacer:** Ese es otro error y tiene otra causa: al Pod le falta declarar alguno de los cuatro campos, y con una cuota de cómputo puesta eso es motivo de rechazo por sí solo, sin importar el tamaño. Le pasa siempre que uno crea un Pod con kubectl run o copia un manifiesto de ejemplo sin bloque resources. Añada requests y limits de CPU y de memoria a todos los contenedores del Pod y vuelva a aplicar. Compruebe cuáles recursos exige el cupo con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard}': cada recurso de cómputo que aparezca ahí es un campo obligatorio en cada contenedor.

- **Síntoma (step 1):** El Pod se creó pero se quedó en Pending y no arranca nunca
  **Qué hacer:** Si el Pod existe, la cuota ya lo admitió: el problema ahora es del planificador, no de la administración de la plaza. Un requests de CPU o de memoria puede caber holgado en el cupo del namespace y aun así no caber en ningún nodo real, porque la cuota mide el namespace entero y el planificador mide una máquina. Lea el motivo textual en los eventos con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza describe pod puesto-de-frutas y compare lo que pide su Pod con lo que tiene libre el nodo, con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig describe node. Este clúster de kind es de un solo nodo, así que un requests de varios GB no va a caber aunque el cupo lo permita.

- **Síntoma (step 2):** El Pod se queda en CreateContainerConfigError y describe habla de una llave que no encuentra
  **Qué hacer:** Un configMapKeyRef o un secretKeyRef que apunta a una llave que no existe impide que el contenedor se configure, y el Pod ni siquiera arranca. Es distinto de un volumen mal puesto, que sí deja arrancar y falla al leer. Liste las llaves reales con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get configmap menu-del-dia -o jsonpath='{.data}' y kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get secret caja-fuerte -o jsonpath='{.data}', y compárelas letra por letra con lo que dice su manifiesto. Un error posible es escribir plato_del_dia con guiones bajos cuando la llave se llama plato-del-dia con guiones.

- **Síntoma (step 2):** Cambió el ConfigMap y la variable de entorno sigue mostrando el valor viejo
  **Qué hacer:** No es un bug: una variable de entorno se calcula una sola vez, cuando el contenedor arranca, y no se vuelve a mirar. El archivo montado sí se actualiza, con un retraso de hasta más o menos un minuto porque el kubelet lo refresca en su propio ciclo. Compruébelo usted mismo: cambie el ConfigMap con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza edit configmap menu-del-dia, espere, y compare kubectl ... exec cocinero -- cat `/etc/menu/plato-del-dia` contra kubectl ... exec cocinero -- printenv PLATO_DEL_DIA. Para que la variable cambie hay que recrear el Pod. Ojo: esta comprobación exige que el ConfigMap tenga los valores del enunciado, así que si experimenta, devuélvalo como estaba antes de calificar.

- **Síntoma (step 3):** El Pod se queda en CreateContainerConfigError con el mensaje container has runAsNonRoot and image will run as root
  **Qué hacer:** El kubelet está cumpliendo la promesa que usted le hizo: le dijo runAsNonRoot true y la imagen no declara ningún usuario, así que iba a correr como root y el kubelet se niega a arrancarla. La imagen de busybox no trae una instrucción USER, por eso hay que decirle el número a mano: añada runAsUser con un uid distinto de cero (por ejemplo 1000) al securityContext del Pod o del contenedor. Vea el mensaje completo con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza describe pod uniformado. Y note que este error es del kubelet, no del API server: el Pod fue admitido, se planificó, y falló al configurar el contenedor.

- **Síntoma (step 3):** El contenedor arranca y se muere enseguida, en bucle, y los logs hablan de Read-only file system
  **Qué hacer:** Su proceso está intentando escribir en una ruta que ahora es de solo lectura, y esa es la reacción normal de casi todo software cuando se le endurece la raíz sin darle dónde escribir. La solución correcta no es apagar readOnlyRootFilesystem: es averiguar en qué ruta escribe y montarle ahí un volumen escribible, normalmente un emptyDir. Lea la ruta exacta en los logs con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza logs uniformado --previous, y añada un volumeMount en esa ruta. Si el proceso escribe en /tmp, monte el emptyDir en /tmp; si escribe en su propio directorio de datos, ahí. Esa es la conversación que usted va a tener con el equipo de la aplicación en el trabajo.

- **Síntoma (step 4):** auth can-i responde no para get configmaps aunque el Role y el RoleBinding existen
  **Qué hacer:** Casi siempre el RoleBinding está apuntando al sujeto equivocado. Un sujeto de tipo ServiceAccount necesita su namespace además de su nombre, y si se le olvida el namespace el binding queda apuntando a una cuenta que no existe, sin dar ningún error. Mire el sujeto real con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get rolebinding el-mesero-lee-el-menu -o yaml y confirme que diga kind ServiceAccount, name carnet-del-mesero y namespace plaza. Otra causa posible es que el roleRef apunte a un ClusterRole cuando usted creó un Role, o al revés: el roleRef es inmutable, así que si está mal hay que borrar el RoleBinding y crearlo otra vez.

- **Síntoma (step 4):** auth can-i responde yes para get pedidos pero el Pod recibe 403 al pedir la lista
  **Qué hacer:** get y list son verbos distintos en RBAC, y pedir una colección entera es list, no get. Este error aparece con recursos personalizados porque uno prueba con kubectl get pedidos, que internamente hace un list, y después el código de la aplicación hace lo mismo. Confirme los dos por separado con kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig auth can-i list pedidos.plaza.example.com -n plaza --as=system:serviceaccount:plaza:carnet-del-mesero y añada list al Role si falta. Y revise el apiGroups de esa regla: para un recurso de CRD tiene que ser el grupo del CRD, plaza.example.com, no la cadena vacía que se usa para los recursos del núcleo.

## Para ir más lejos

- Añádale un LimitRange al namespace plaza con un default y un defaultRequest de CPU y memoria, y después intente crear un Pod sin bloque resources. Verá que ahora sí lo admiten, porque el LimitRange le rellena los campos antes de que la cuota lo revise, y que el Pod resultante tiene requests y limits que usted nunca escribió. Compare eso con lo que le pasó en el Paso 1 y saque su propia conclusión sobre cuál de los dos objetos conviene poner primero en un namespace compartido.
- Cambie el valor de una llave del ConfigMap menu-del-dia con kubectl edit y no toque el Pod cocinero. Espere un minuto y compare lo que devuelve el cat del archivo montado contra lo que devuelve el printenv de la variable. Cronometre cuánto tarda el archivo en cambiar, que depende del ciclo de sincronización del kubelet, y anote la diferencia: es la razón por la que una aplicación que relee su configuración desde un archivo montado se puede reconfigurar sin reiniciar y una que la lee del entorno no. Devuelva el ConfigMap a los valores del enunciado antes de volver a calificar el Paso 2.
- Aplíquele al namespace plaza las etiquetas de Pod Security Admission en modo warn, con pod-security.kubernetes.io/warn=restricted, y después vuelva a crear los Pods de los Pasos 2 y 4 tal como los tiene. Lea con calma los avisos que le imprime el API server sobre cada campo que falta, y compárelos con el securityContext que usted le puso al Pod del Paso 3. Ese ejercicio le dice, sin romper nada, cuánto le falta a sus manifiestos cotidianos para pasar el perfil restringido.
- Escriba un Role adicional que le permita al carnet-del-mesero hacer create y update sobre pedidos.plaza.example.com, pero solo sobre el objeto llamado pedido-de-la-mesa-4, usando el campo resourceNames de la regla. Después compruebe con auth can-i --subresource y con el nombre del recurso qué responde el API server, y observe que resourceNames no aplica a los verbos de colección como list. Esa asimetría es una de las cosas que más sorprenden cuando uno diseña permisos finos por primera vez.

## Referencias

- Kubernetes Project, Resource Quotas. Primary source for the ResourceQuota object, for the rule that a compute quota makes requests and limits mandatory on every container in the namespace, and for the requested/used/limited breakdown in the rejection message Step 1 reads. https://kubernetes.io/docs/concepts/policy/resource-quotas/
- Kubernetes Project, Resource Management for Pods and Containers. Primary source for the requests and limits fields, for CPU and memory units such as 200m and 128Mi, and for how the scheduler uses requests, which Step 1's troubleshooting distinguishes from quota admission. https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- Kubernetes Project, ConfigMaps. Primary source for consuming a ConfigMap as environment variables with configMapKeyRef and as a mounted volume where each key becomes a file, and for the fact that mounted files are updated while environment variables are not. https://kubernetes.io/docs/concepts/configuration/configmap/
- Kubernetes Project, Secrets. Primary source for the Opaque type, for the base64 encoding of the data field being encoding and not encryption, for secretKeyRef and for secret volumes, all of which Step 2 both builds and grades. https://kubernetes.io/docs/concepts/configuration/secret/
- Kubernetes Project, Configure a Security Context for a Pod or Container. Primary source for runAsUser, runAsGroup, fsGroup, runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation and capabilities, and the task page whose procedure Step 3 follows when it reads the process identity from inside the container. https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- Kubernetes Project, Pod Security Standards. Defines the baseline and restricted profiles whose requirements Step 3's uniform matches, and the source for the extension that turns the restricted profile on in warn mode. https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Kubernetes Project, Using RBAC Authorization. Primary source for Role, ClusterRole, RoleBinding and ClusterRoleBinding, for the ServiceAccount subject needing a namespace, for the immutability of roleRef, and for the distinction between the get and list verbs that Step 4's troubleshooting turns on. https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Kubernetes Project, Authorization Overview. Documents kubectl auth can-i, including the --as impersonation flag and the --all-namespaces form, which is the tool Step 4 is graded with on both the allowed and the forbidden side. https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- Kubernetes Project, Managing Service Accounts and Configure Service Accounts for Pods. Primary source for serviceAccountName, for automountServiceAccountToken, and for the projected token, ca.crt and namespace files under /var/run/secrets/kubernetes.io/serviceaccount that Step 4 reads and uses from inside the Pod. https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- Kubernetes Project, Extend the Kubernetes API with CustomResourceDefinitions. Primary source for the CRD the setup installs, for the group, plural, scope and served/storage version fields, and for the fact that a custom resource is named in an RBAC rule with its own apiGroup, which Step 4 requires. https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/
- kubernetes-sigs/kind, release v0.32.0. Publishes the pre-built node images for this kind release, including the kindest/node:v1.36.1 digest the setup script pins, and documents the --config and --kubeconfig flags this lab uses to build its own cluster without touching any other kubeconfig. https://github.com/kubernetes-sigs/kind/releases/tag/v0.32.0
- kind Project, Quick Start. Documents kind create cluster and kind delete cluster with the --name flag and the kubeconfig handling that keeps this lab's cluster isolated in a private file. https://kind.sigs.k8s.io/docs/user/quick-start/

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
