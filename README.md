# Lo que pasa es que desarrollar en Kubernetes

**Los laboratorios del libro.** · **The book's labs.**

Si usted llegó aquí desde el libro, está en el lugar correcto. Aquí están los laboratorios del
libro, uno por cada parte, listos para clonar y ejecutar.

If you got here from the book, you are in the right place. These are the book's labs, one per
part, ready to clone and run.

---

## Español

### El libro

**Lo que pasa es que desarrollar en Kubernetes.** *Guía completa de desarrollo de aplicaciones en Kubernetes en lenguaje sencillo.*
Quince capítulos en cinco partes, con un laboratorio por parte. Cubre los dominios de la
certificación **CKAD** (Certified Kubernetes Application Developer): diseño y construcción de
aplicaciones, despliegue, observabilidad y mantenimiento, entorno, configuración y seguridad, y
servicios y redes. Es un libro con la misma apuesta del resto de la serie: si usted entiende el
mecanismo, no tiene que memorizar la respuesta. La analogía es el negocio de comida La Buena
Sazón, que empieza en un puesto de plaza de mercado y termina como franquicia.

Material de estudio independiente. No está afiliado a la Linux Foundation ni a la Cloud
Native Computing Foundation, ni cuenta con su respaldo. Los laboratorios imitan el formato
de la certificación (tareas calificadas por el estado final del clúster) y nunca su contenido.

### Qué son estos laboratorios

Cada laboratorio es una práctica de 45 a 60 minutos de trabajo real contra un clúster de
verdad (kind, dentro de Docker). Cada paso le da un objetivo y un entregable, y se califica
por el **estado final del clúster**, no por lo que usted escribió ni por el camino que tomó.
Cada laboratorio se publica aquí solo después de ejecutarlo completo en kind, de principio a fin.

### Cuándo hacer cada laboratorio

Hay un laboratorio por cada parte del libro, y cada uno usa **todo** lo de esa parte, no
solo el último capítulo. El momento de hacerlo es cuando usted termina la parte completa.

| Termine de leer | Y entonces corra | Tiempo | Puntos |
|---|---|---|---|
| Capítulo 3, *El ayudante de cocina y la nevera compartida* (cierra la Parte I) | `es/lab-part-01` | 55 min | 40 |
| Capítulo 6, *La franquicia con instrucciones de armado* (cierra la Parte II) | `es/lab-part-02` | 55 min | 40 |
| Capítulo 8, *El libro de quejas y reclamos, y el catálogo que cambió de página* (cierra la Parte III) | `es/lab-part-03` | 60 min | 40 |
| Capítulo 12, *El carné del empleado y el uniforme obligatorio* (cierra la Parte IV) | `es/lab-part-04` | 55 min | 40 |

El laboratorio de la Parte V se agrega aquí cuando termine su
ejecución completa en kind.

### Antes de empezar

Necesita estas herramientas instaladas y funcionando:

| Herramienta | Para qué | Versión con la que se probó |
|---|---|---|
| `docker` | correr los nodos del clúster y construir la imagen de la Parte I | 29.9.0 |
| `kind` | crear los clústeres de práctica | v0.33.0 |
| `kubectl` | hablarle al clúster | v1.37.0 |
| `helm` | instalar el chart de la Parte II | v4.3.0 |
| `jq` | leer las respuestas del clúster en los verificadores | 1.7 o superior |

Versiones cercanas también sirven. Los clústeres se crean con la imagen `kindest/node:v1.36.1`,
fijada por digest, y los laboratorios necesitan internet al montarse.

### Empiece aquí

```bash
git clone https://github.com/lfarizav/lo-que-pasa-es-que-desarrollar-en-kubernetes.git
cd lo-que-pasa-es-que-desarrollar-en-kubernetes/es/lab-part-01
cat README.md
```

El repositorio tiene dos carpetas: `es/` (español) y `en/` (inglés). Los scripts son los
mismos; cambia el idioma del `README.md` de cada laboratorio. Cada laboratorio se corre
siempre igual: montaje, cada paso con su verificador, y desmontaje.

```bash
./00-setup.sh                  # crea el clúster y deja todo listo
./01-step.sh && ./01-check.sh  # haga el paso, compruebe que quedó bien
./02-step.sh && ./02-check.sh
./99-teardown.sh               # borra el clúster y el espacio de trabajo
```

El verificador imprime `ok` cuando el paso quedó bien y sale con error cuando no. Los
`0N-step.sh` están para que no se quede atascado, pero el laboratorio se aprovecha leyendo el
`README.md` y escribiendo usted los comandos: corra el script para comparar.

### Su clúster de todos los días no se toca

Cada laboratorio crea su propio clúster kind, con su propio archivo de kubeconfig en
`~/ckad-lab/pNN/kubeconfig`, y **todos** los `kubectl` del laboratorio pasan `--kubeconfig`
de forma explícita. Su `~/.kube/config` no se lee ni se modifica, y el `99-teardown.sh` borra
únicamente el clúster de ese laboratorio, por nombre. Sus otros clústeres de kind siguen donde
estaban. Nunca corra en producción un comando de un libro, de un blog o de un video sin
entender qué hace. Este libro incluido.

### Qué hace cada laboratorio

| | Capítulos | Laboratorio |
|---|---|---|
| 1 | 1 a 3 | la receta que usted mismo empaca y mete al clúster, el encargo que se acaba en vez de repetirse para siempre, el pan que se hornea solo cada madrugada, y el ayudante que deja la nevera lista antes de que el cocinero abra |

### Si algo no funciona

Revise primero el `README.md` del laboratorio (sección de problemas frecuentes). Si el
problema sigue, abra un issue contando qué comando falló, con la versión de Kubernetes y el
sistema operativo. Los reportes de error son bienvenidos.

---

## English

### The book

**Here's What's Actually Going On with Kubernetes Application Development.** *The complete Kubernetes application development guide in plain language.*
Fifteen chapters in five parts, with one lab per part. It covers the domains of the **CKAD**
(Certified Kubernetes Application Developer) certification: application design and build,
deployment, observability and maintenance, environment, configuration and security, and
services and networking. It makes the same bet as the rest of the series: once you understand
the mechanism, there is no answer left to memorize. The analogy is the food business La Buena
Sazón, which starts as a market stall and ends up as a franchise.

Independent study material. Not affiliated with, endorsed by, or sponsored by the Linux
Foundation or the Cloud Native Computing Foundation. The labs emulate the certification's
format (tasks graded on the final state of the cluster) and never its content.

### What these labs are

Each lab is 45 to 60 minutes of real work against a real cluster (kind, inside Docker). Each
step gives you an objective and a deliverable, and is graded on the **final state of the
cluster**, not on what you typed or the path you took. Each lab is published here only after a
complete run on kind, from start to finish.

### When to do each lab

There is one lab per part of the book, and each one uses **everything** in that part, not
just the last chapter. The moment to do it is when you finish the whole part.

| Finish reading | Then run | Time | Points |
|---|---|---|---|
| Chapter 3, *The Kitchen Helper and the Shared Fridge* (closes Part I) | `en/lab-part-01` | 55 min | 40 |
| Chapter 6, *The Franchise With Assembly Instructions* (closes Part II) | `en/lab-part-02` | 55 min | 40 |
| Chapter 8, *The Complaints Book, and the Catalog That Changed Page* (closes Part III) | `en/lab-part-03` | 60 min | 40 |
| Chapter 12, *The Employee ID Card and the Mandatory Uniform* (closes Part IV) | `en/lab-part-04` | 55 min | 40 |

The Part V lab is added here once it completes its full run on kind.

### Before you start

You need these tools installed and working:

| Tool | What for | Version this was tested on |
|---|---|---|
| `docker` | running the cluster's nodes and building the Part I image | 29.9.0 |
| `kind` | creating the practice clusters | v0.33.0 |
| `kubectl` | talking to the cluster | v1.37.0 |
| `helm` | installing the Part II chart | v4.3.0 |
| `jq` | reading the cluster's answers in the graders | 1.7 or later |

Nearby versions are fine too. The clusters are created from `kindest/node:v1.36.1`, pinned by
digest, and the labs need internet access when they are set up.

### Start here

```bash
git clone https://github.com/lfarizav/lo-que-pasa-es-que-desarrollar-en-kubernetes.git
cd lo-que-pasa-es-que-desarrollar-en-kubernetes/en/lab-part-01
cat README.md
```

The repository has two folders: `es/` (Spanish) and `en/` (English). The scripts are the
same; what changes is the language of each lab's `README.md`. Every lab runs the same way:
setup, each step with its grader, and teardown.

```bash
./00-setup.sh                  # creates the cluster and gets everything ready
./01-step.sh && ./01-check.sh  # do the step, then check that it landed
./02-step.sh && ./02-check.sh
./99-teardown.sh               # deletes the cluster and the workspace
```

The grader prints `ok` when the step is right and exits with an error when it is not. The
`0N-step.sh` scripts are there so you never get stuck, but you get the most out of a lab by
reading its `README.md` and typing the commands yourself: run the script to compare.

### Your everyday cluster is never touched

Each lab creates its own kind cluster with its own kubeconfig file at
`~/ckad-lab/pNN/kubeconfig`, and **every** kubectl in the lab passes `--kubeconfig`
explicitly. Your `~/.kube/config` is neither read nor modified, and `99-teardown.sh` deletes
only that lab's cluster, by name. Your other kind clusters stay exactly where they were. Never
run a command from a book, a blog or a video on a production cluster without understanding
what it does. This book included.

### What each lab does

| | Chapters | Lab |
|---|---|---|
| 1 | 1 to 3 | the recipe you pack yourself and push into the cluster, the errand that finishes instead of repeating forever, the bread that bakes itself every small hour, and the helper who stocks the fridge before the cook clocks in |

### If something does not work

Check the lab's `README.md` first (troubleshooting section). If the problem persists, open an
issue saying which command failed, with your Kubernetes version and operating system. Bug
reports are welcome.

---

_Hecho con ❤️ por Luis Felipe Ariza Vesga._
