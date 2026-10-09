# Part I - Lab: the recipe you pack yourself and push into the cluster, the errand that finishes instead of repeating forever, the bread that bakes itself every small hour, and the helper who stocks the fridge before the cook clocks in

- Time: 55 min
- Points: 40

## Objective

This is an Exam-Style lab: each step tells you only the objective and the deliverable, and that step's exact command sequence lives in its cmd field for you to reveal after you have tried on your own. Step 1 has you pack a recipe: you build an image with docker from the Dockerfile the setup leaves on disk, push it into the kind cluster with kind load docker-image, and put it to work as a two-replica Deployment, and grading demands that the running container come from THAT image and not from some public one you pulled to get out of trouble (Chapter 1). Step 2 has you pick the type of business: there is a batch task that has to finish, and the right answer is a Job with completions and backoffLimit, not a Deployment; the check demands that a Job did the work, that the Job is complete, and that no Deployment and no ReplicaSet was left standing in as a substitute in the namespace (Chapter 2). Step 3 has you schedule the small-hours bread with a CronJob that carries a schedule and history limits, and the check is not satisfied by the object merely existing: it demands the CronJob has already fired, that the Jobs belong to it rather than being hand-made, and that the history limit is still set and still ruling (Chapter 2). Step 4 closes with the kitchen helper: an init container that leaves the work done in a shared emptyDir fridge, and a main container that serves exactly that, with the check stepping into the main container to read the file and to ask for it over HTTP (Chapter 3). No check reads your command history: all four re-query the live cluster at grading time, three of them walk into a container and look with their own eyes, and the first one also opens the node's containerd to confirm where the image came from.

## Prerequisites

- A Linux machine with kind, kubectl, docker and jq on PATH, and at least 3 GB of free RAM for the cluster. The lab creates its own kind cluster named ckad-p01 and deletes it in the teardown.
- ISOLATION, and this is not a matter of style. This lab's cluster NEVER touches your everyday kubeconfig: it is created with --kubeconfig ~/ckad-lab/p01/kubeconfig from the very first command, and absolutely every kubectl in the lab passes --kubeconfig and --context explicitly. If you already have other kind clusters running on this machine, this lab does not see them, does not modify them and does not delete them. Check it yourself: the setup ends by printing a kubectl config get-contexts with no --kubeconfig, and ckad-p01 must not show up there at all.
- Internet access when you set the lab up and during Steps 2, 3 and 4: kind pulls the node image, and the node's containerd pulls the digest-pinned busybox image the Job, the CronJob and the init-container Pod all use. Step 1 is the only one that needs NO registry, because its image is built on your machine and pushed into the node with kind load. The Docker daemon has to be running the whole time, because both Step 1 and its check talk to it.
- PINNED VERSIONS, verified on 2026-08-21 on this same machine. kind v0.32.0. kubectl v1.36.1. Docker 29.7.2. jq 1.7. Node image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, which is that kind release's default image and which is passed explicitly here with --image because a tag is mutable and a digest is not. Base image for the recipe and for the next three steps busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirm what you actually got with kind version and kubectl version, never from memory.
- Having read Chapters 1 to 3. This lab does not re-explain what a container image is, or when a Job is used instead of a Deployment, or what an init container is for; it makes you operate all three against a real cluster and grades the end state.

## Steps

The `0N-step.sh` is there so you never get stuck: read the step, try it on your own first, and run the script when you want to compare. It also writes the answer file the step asks for, reading the values from the live cluster.

### 1. Ch. 1: The recipe gets packed once and carried into the kitchen, it is not borrowed from the neighbour (10 pts)

Chapter 1 explained that a container image is the packed recipe: not the plated dish, but everything needed for any kitchen in the world to make that dish identically. Here's what's actually going on: between understanding that and doing it there is a step that is easy to skip over, and it is the dullest and the most important one: the recipe has to physically reach the kitchen where it will be cooked.

The cluster does not lean over into your computer to see what you built. When the kubelet is handed a Pod it goes looking for that image in a registry, and if the name is not there it returns an ImagePullBackOff without an ounce of pity. That is why kind ships a command made for local development, kind load docker-image, which takes the image from your machine's docker and pushes it into the node's containerd. It is literally loading the pot into the car and driving it to the diner.

And here is the detail that clicks. When you look at the Pod's imageID you will not see the name you gave it. You will see something that says import with today's date stuck on. That odd name is the signature of an image that came in the back door, carried by hand, not through a registry. A container pulled from docker.io never looks like that, which is why that field is the most honest proof that you really did the work.

The other detail that sticks is the long name. You write la-receta:1.0, and the node's containerd lists it as docker.io/library/la-receta:1.0, because every short name gets normalized into that shape. Nobody uploaded your image to Docker Hub: that prefix is the name's default, not a download address.

And finally the pull policy. You will not write it and it will still come out IfNotPresent. That happens because the tag is not latest. Had you tagged that image latest, the default policy would have been Always, the kubelet would have gone off to the registry to find it, and your Pod would have fallen over even though the image was sitting right there on the node. That is why this step forbids Always: not a whim, but how local development with kind works.

DELIVERABLE: the image `la-receta:1.0` built from `~/ckad-lab/p01/receta/Dockerfile`, loaded into the ckad-p01 cluster, and a Deployment named `el-restaurante` in namespace `la-cocina` with 2 ready replicas, whose container asks for exactly that image and does NOT use imagePullPolicy Always. Plus the file `~/ckad-lab/p01/01-respuesta.txt`, exactly 4 lines:

```text
REPLICAS_LISTAS=<how many replicas the Deployment reports as ready>
IMAGEN_DEL_DESPLIEGUE=<the image the Pods ask for, exactly as it reads in the spec>
IMAGEN_EN_EL_NODO=<the full name the node's containerd lists that image under>
LO_QUE_SIRVE_LA_CARTA=<the line of text the container returns on port 8080>
```

<details>
<summary>What you should see</summary>

The Dockerfile the setup left you starts with a digest-pinned busybox FROM, creates /carta, copies carta.html in as index.html and ends with a CMD that starts busybox's httpd on port 8080 serving that folder. The docker build ends on the line naming to docker.io/library/la-receta:1.0, and docker image ls shows you the newborn image. The kind load prints that the image with that ID was not yet on node ckad-p01-control-plane and that it is loading it. The node's crictl then lists it, and look carefully at how it lists it: it does not say plain la-receta:1.0, it says docker.io/library/la-receta, because containerd normalizes every short name into that long form. The rollout ends on successfully rolled out. And the line genuinely worth reading is the Pods one: the pull policy came out IfNotPresent on its own, without you writing it, because the tag is not latest, and the imageID says la-receta nowhere at all, it says docker.io/library/import-<today's date>@sha256:<whatever>. That import name with the date is kind load's fingerprint: an image pulled from a registry would never look like that. The last command hands you back the menu: la-carta-del-restaurante-v1.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 2. Ch. 2: An errand gets delivered and then it is over, it does not stay open forever (10 pts)

Chapter 2 laid the catalogue of businesses on the table: the Deployment for what has to stay open, the DaemonSet for what goes one per branch, the StatefulSet for what has its own name and its own storeroom, and the Job for what gets done and is then over. Here's what's actually going on: in real life you do not pick from a list, you pick by reflex, and the handiest reflex is the Deployment.

A Deployment has an obsession written into its nature: keep N replicas alive. If your process does its work and exits cleanly, with status 0, the Deployment reads that as a crash and starts it again. And again. And again. You end up with a container in CrashLoopBackOff that never once failed, and a log full of successes the cluster reads as disasters. It is hiring a permanent employee to deliver one single lunch, then firing and rehiring them every time they arrive.

The Job exists for exactly this. You tell it how many times the thing has to come out right with completions, how many at a time with parallelism, and how many retries it tolerates before giving up with backoffLimit. That last one is easy to take for granted, and its default will surprise you when you look at it with explain: it is not 0 and it is not 1.

And there is a practical consequence worth the whole chapter: when the Job finishes, the Pods are NOT deleted. They stay in phase Succeeded with their full logs, waiting for you to read them. That is why a Job is debuggable and a Deployment doing batch work is not: in the Deployment the Pod you cared about was already replaced three times before you finished typing kubectl logs.

This step asks you to process the six lunch errands. Pick the business.

DELIVERABLE: in namespace `los-encargos`, a Job named `los-encargos-del-almuerzo` with `completions: 6` and `backoffLimit: 2`, already complete, whose six Pods still exist in phase Succeeded. That namespace must hold NO Deployment, ReplicaSet, StatefulSet or DaemonSet, and the Job must NOT carry ttlSecondsAfterFinished. Plus the file `~/ckad-lab/p01/02-respuesta.txt`, exactly 3 lines:

```text
DUENO_DE_LOS_PODS=<the Kind that shows up in the ownerReferences of the namespace's Pods>
ENCARGOS_COMPLETADOS=<how many Pods the Job reports as successful>
REINTENTOS_PERMITIDOS=<the backoffLimit value the Job ended up with>
```

<details>
<summary>What you should see</summary>

The batch group's api-resources shows you exactly two things live there, cronjobs and jobs, and nothing else. The explain on completions tells you it is the number of Pods that have to finish successfully for the Job to count as done, and the one on backoffLimit gives you a fact worth checking instead of assuming: the default is 6 retries, not 0 and not 1. Then the Job is created and the wait returns condition met in under a minute. The status line reads 6 completions, backoffLimit 2, exitosos 6. The six Pods are listed in phase Succeeded, not Running, and on all six the owner is Job: notice the Pods do NOT vanish when the Job finishes, they stay put with their logs intact, which is exactly what makes a Job debuggable and a Deployment not. And the last line is the most eloquent of all: No resources found in los-encargos namespace, because this namespace holds no Deployment, no ReplicaSet, no StatefulSet and no DaemonSet. A Job did the work on its own.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 3. Ch. 2: The small-hours bread bakes itself, and the bakery does not keep every tray it ever used (10 pts)

A Job is an errand. A CronJob is the habit. Here's what's actually going on: in the diner there are things nobody orders. The small-hours bread comes out every day at the same time because it always has, and nobody has to call the baker to remind him.

A CronJob does not do the work. It matters that this is clear, because it is easy to mix up: the CronJob is a factory for Jobs. When its minute arrives it creates a Job, and that Job creates the Pod that actually does the work. That is why the ownerReferences chain has three links and not two, and why the Job names come out with a long number stuck on the end, which is not random: it is the exact minute it was due to run.

And here is the part that is easy to leave at its default until the cluster fills up: a CronJob does not delete its past just because. It keeps a history of finished Jobs, and that history has a default value you have to go look up with explain instead of assuming it. A CronJob running every minute with nobody limiting it leaves you a pile of dead objects in the namespace, and the day you go to list Jobs you will not find the one you cared about. The bakery does not keep every tray it has ever used: it keeps the last few and throws out the rest.

There is a patience detail that is also an exam detail: a freshly created CronJob does NOT run at that instant. It runs when its minute arrives according to the schedule. That is why this step uses an every-minute schedule, so you can see the full cycle without falling asleep waiting, and why the step's command sits in a loop until status.lastScheduleTime stops being empty.

DELIVERABLE: in namespace `la-madrugada`, a CronJob named `el-pan-de-la-madrugada` with `schedule: "*/1 * * * *"`, `successfulJobsHistoryLimit: 2` and `failedJobsHistoryLimit: 1`, not suspended, that has ALREADY fired at least once and has at least one Job of its own finished successfully. That namespace must hold no hand-made Job, meaning none without ownerReferences. Plus the file `~/ckad-lab/p01/03-respuesta.txt`, exactly 3 lines:

```text
HORARIO_DEL_PAN=<the exact value of the schedule field>
HISTORIAL_DE_EXITOSOS=<how many successful Jobs the CronJob keeps>
DUENO_DE_LOS_EMPLEOS=<the Kind that shows up in the ownerReferences of the namespace's Jobs>
```

<details>
<summary>What you should see</summary>

The three explains hand you the three facts this step needs and that are worth reading rather than recalling: schedule uses cron syntax, successfulJobsHistoryLimit keeps 3 successful Jobs by default, and failedJobsHistoryLimit keeps 1 failed one by default. The CronJob is created and the first get shows a table with SCHEDULE, TIMEZONE at none, SUSPEND at False, ACTIVE at 0 and LAST SCHEDULE at none, because it has not fired yet. That is why the lab sits and waits: a freshly created CronJob does not run right away, it runs when its minute arrives. Within a minute or less the status line already carries a real timestamp in ultima. The Jobs listing shows exactly one, with a name that is the CronJob's plus a long number stuck on, and with dueno=CronJob: that number is the Unix minute it was due to run, which is why two executions never collide on name. The exitosos field can come back empty if you happened to look while the Pod was still working; look again in a few seconds and it says 1. The logs command prints the baker's line with the UTC time of the bake.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 4. Ch. 3: The helper stocks the fridge and leaves, and the cook finds everything ready (10 pts)

Chapter 3 introduced the kitchen helper: the one who arrives before everybody, chops, washes, leaves the pots ready, and is gone by the time the cook opens the door. In Kubernetes that person is called an init container, and the job is to prepare the ground.

Here's what's actually going on: an init container is not a smaller container or a lesser-grade container. It is a container that runs BEFORE, in order, one after another, and that has to finish successfully for the next one to start. If the helper falls over, the cook does not open. Ever. The Pod sits in Init with the number of the one that failed, and there is nothing to restart there but the helper itself.

And then comes the question that separates theory from practice: if the helper leaves before the cook arrives, how is the work handed over? It is not passed through the door. Each container has its own isolated filesystem, so whatever the helper writes on its own disk leaves with it. The handover happens in the shared fridge: an emptyDir volume mounted by both.

An emptyDir is exactly what the name says. It is born empty when the Pod lands on a node, lives as long as the Pod lives, and is deleted without ceremony when the Pod goes. It is not storage, it is a shared worktable between the containers of one Pod. And note the effect that sometimes surprises people: if the main container had a file at that path baked into its image, mounting the emptyDir covers it up. That is why this step cannot be solved by baking the file into the image.

DELIVERABLE: in namespace `la-nevera`, a Pod named `el-almuerzo-del-dia`, Running and Ready, under these conditions: a volume of type `emptyDir` mounted by both the init container and the main container; an init container that finishes with reason Completed and exit code 0 and that leaves in that volume a file `index.html` whose only line is exactly `el-ayudante-dejo-listo-el-mise-en-place`; a main container that serves that same folder over HTTP on the container's port 8080. Both containers must use the pinned image `busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0`. Plus the file `~/ckad-lab/p01/04-respuesta.txt`, exactly 3 lines:

```text
ESTADO_DEL_AYUDANTE=<the reason the init container finished with>
TIPO_DE_VOLUMEN=<the type of the volume the two containers share>
LO_QUE_SIRVE_LA_COCINA=<the line the main container returns on port 8080>
```

<details>
<summary>What you should see</summary>

The two explains confirm what the chapter promised: init containers run in order, before the ordinary containers, and if one fails the Pod is considered failed and handled according to its restartPolicy; and an emptyDir is a temporary directory that shares the Pod's lifetime. The Pod is created and the wait returns condition met in a few seconds. The init container's status says el-ayudante -> Completed, and that word matters: it does not say Running and it does not say Succeeded, it says Completed, because a finished init container reports in the terminated block with that reason. The volume listing shows two, and there is a useful surprise there: alongside your la-nevera volume of type emptyDir there is one called kube-api-access-<something> of type projected, which you did not write and which Kubernetes injects into every Pod to hand it its ServiceAccount token. The last two commands return the same line, el-ayudante-dejo-listo-el-mise-en-place: the first by reading the file from the cook's own filesystem, the second by asking httpd for it on port 8080. That the two match is the complete demonstration: the helper wrote it, the cook has it, and the cook is serving it.

</details>

```bash
./04-step.sh
./04-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

## How to run it

```bash
./00-setup.sh                  # creates the cluster and sets everything up
./01-step.sh && ./01-check.sh  # do the step, check it landed
./02-step.sh && ./02-check.sh
./03-step.sh && ./03-check.sh
./04-step.sh && ./04-check.sh
./99-teardown.sh               # deletes the cluster and the workspace
```

## Troubleshooting

- **Symptom (step 1):** The Pods sit in ErrImagePull or ImagePullBackOff even though you built the image
  **What to do:** Two causes, worth separating. The first: you forgot the kind load, or you did it against another cluster. Check by looking inside the node with docker exec ckad-p01-control-plane crictl images, which is the only source that tells the truth about what the node holds; if it is not there, your machine's docker does not count. The second: the image is on the node but you left imagePullPolicy at Always, so the kubelet ignores what it already has and goes off to docker.io, where it does not exist. With any tag other than latest the default policy is already IfNotPresent, so the normal move is not to write it at all.

- **Symptom (step 1):** kind load fails with ctr: content digest ... not found
  **What to do:** That error appears when the image you hand it is a multi-platform index of which your docker only pulled one platform, which is exactly what happens if you try to load busybox directly. The image this step asks you to load is the one you build, and that one comes out single-platform, so it loads without trouble. If you hit the error anyway, rebuild with docker build --platform linux/amd64 or with DOCKER_BUILDKIT=0. The setup already ran this same probe and would have told you ERROR DE SUSTRATO: KIND-LOAD-NO-FUNCIONA before letting you start.

- **Symptom (step 1):** The wget inside the Pod returns nothing or says connection refused
  **What to do:** Check you are asking for port 8080 and not 80: busybox's httpd only listens where -p tells it to, and the setup's Dockerfile says 8080. And remember EXPOSE in a Dockerfile is pure documentation, it opens nothing and publishes nothing in Kubernetes; the port is open because the process opens it, not because the Dockerfile mentions it.

- **Symptom (step 2):** The Job is created but rejected with an error about restartPolicy
  **What to do:** A Job's Pod template only accepts restartPolicy Never or OnFailure, never Always, which is the default for an ordinary Pod. If you copied a template from a Deployment and left that field alone, that is your error. Write restartPolicy: Never inside spec.template.spec, which is where it belongs, not inside the Job's own spec.

- **Symptom (step 2):** kubectl wait --for=condition=Complete waits forever
  **What to do:** Look at the Pods first with kubectl -n los-encargos get pods. If they are in ImagePullBackOff, the node could not fetch the image and the Job is not the problem. If they are in Error, your command returned a non-zero status and the Job will retry until it exhausts backoffLimit and then mark the Failed condition instead of Complete. Read a failed Pod's log with kubectl -n los-encargos logs <pod>, which is exactly why a Job's Pods are not deleted.

- **Symptom (step 2):** You deleted and recreated the Job and now kubectl apply complains about immutable fields
  **What to do:** A created Job's selector and template cannot be edited, the same way roleRef cannot in RBAC. When you got completions or backoffLimit wrong, the only way out is kubectl delete job <name> and reapply the corrected manifest. Delete with --wait=true so the old Pods are gone before the new one is created, or you will see Pods from two generations at once and the check will over-count.

- **Symptom (step 3):** LAST SCHEDULE stays at none and no Job shows up
  **What to do:** First, patience: on an every-minute schedule it can take up to 60 seconds, and the controller checks in cycles, so 70 or 80 seconds is not unusual either. If it takes much longer, check two fields. suspend has to be false, and if you set it to true the object exists but never fires. And check the schedule has five space-separated fields: a malformed schedule is rejected at creation, but a well-formed odd one like 0 3 1 1 * is accepted and simply will not come up today.

- **Symptom (step 3):** The Jobs pile up and there are already ten in the namespace
  **What to do:** That is the exact symptom of not having set the history limits, or of having set them in the wrong place. They go in the CronJob's spec, at the same level as schedule, NOT inside jobTemplate. A kubectl -n la-madrugada get cronjob el-pan-de-la-madrugada -o yaml shows you where they really landed. Once you fix them with an apply, the controller collects the excess on its own during the next cycle, there is nothing to delete by hand.

- **Symptom (step 3):** kubectl logs finds nothing even though the Job says it succeeded
  **What to do:** That bake's Pod was most likely collected along with its Job by the history limit, which is precisely the behavior this step has you configure. List the live Jobs first with kubectl -n la-madrugada get jobs and ask for the most recent one's log. The label tying a Pod to its Job is batch.kubernetes.io/job-name, which lets you request logs by selector without copying names by hand.

- **Symptom (step 4):** The Pod sits at Init:0/1 or Init:Error and never reaches Running
  **What to do:** The helper did not finish cleanly and the cook will not open until it does. Ask for the init container's log by name, because kubectl does not show it unless you ask: kubectl -n la-nevera logs el-almuerzo-del-dia -c el-ayudante. The commonest error is writing to a path that is not mounted, for instance mounting the volume at /nevera but writing to /nevera/html/index.html without that subdirectory existing. Remember the command runs in a container shell, so if you need mkdir -p, put it first on the same line.

- **Symptom (step 4):** The cook is Running but the wget returns 404 File not found
  **What to do:** The file is not where httpd looks for it. Compare three things: the volume's mountPath in the main container, the path httpd receives with -h, and the path the init container wrote to. All three have to point at the same place. A classic mistake is mounting the same volume at two different paths in each container, which Kubernetes accepts without complaint because it is perfectly legal, and the file really is there, just at a different address from the one the cook is looking at.

- **Symptom (step 4):** kubectl exec answers that you have to choose a container
  **What to do:** A Pod with several containers forces you to say which one you are entering, with -c <name>. And mind this detail: you cannot exec into a finished init container, because its process does not exist; from that one you can only read logs. The proof that the handover worked is always done from the main container, which is the one that is alive and has the fridge mounted.

## Going further

- Break Step 1 on purpose to see the whole problem. Retag your image as la-receta:latest, create a new Deployment with that tag, and watch which pull policy you get without writing it and what the Pod does. Then fix it both possible ways, setting imagePullPolicy: IfNotPresent by hand or going back to a versioned tag, and keep the conclusion: in local development the latest tag is not a name, it is an order to go out to the internet.
- Do on purpose what Step 2 forbids and see it with your own eyes. Create a Deployment with the same image and the same command as the Job, one replica, and sit watching kubectl get pods -w for a minute. Count the restarts. Read the Pod's log and confirm the process exited cleanly every single time. Now you know why CrashLoopBackOff does not always mean something failed: sometimes it means something finished, somewhere finishing is forbidden.
- Give Step 3's CronJob a jobTemplate that always fails, with a command exiting 1, and let it run for five minutes. Count how many failed Jobs stay retained and compare that with failedJobsHistoryLimit. Then play with concurrencyPolicy: use a command that takes 90 seconds on an every-minute schedule and compare what happens with Allow, with Forbid and with Replace. All three values are documented in the field's explain and each tells a different story about what to do when the previous bake is still in the oven.
- Extend Step 4 to two helpers and check the ordering. Add a second init container that appends a second line to the same file with >>, put it first in the list and then put it second, and compare the resulting file: the list order is the execution order and there is nothing to negotiate. Then make the first one exit 1 and use kubectl describe pod to see where the Pod gets stuck and what the second helper's status says, given it will not even have started.

## References

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
