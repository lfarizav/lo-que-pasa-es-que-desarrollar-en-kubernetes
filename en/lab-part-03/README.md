# Part III - Lab: the oven switched off every fifteen seconds, the counter that never raises the open sign, the complaint left in last round's book, and the catalog that changed page

- Time: 60 min
- Points: 40

## Objective

This is an Exam-Style lab and it is pure DIAGNOSTICS: each step states only the objective, and that step's exact command sequence lives in its cmd field for you to reveal AFTER you have tried to solve it with your own hands. All four steps start with the system already broken, because the setup script applies four faults from base64-encoded payloads. That is not cryptography and does not pretend to be: it is a courtesy blindfold, so you do not read the answer in the same script that breaks the cluster. The faults are identical for every reader on every run, and the full answer key sits in each step's cmd field. Step 1 hands you a healthy application whose container the kubelet is killing every few seconds, and you have to reach the event that explains it before touching anything (Chapter 7). Step 2 hands you two replicas running, a published Service and zero addresses in the directory, and you have to work out why running is not the same as ready (Chapter 7). Step 3 hands you a Pod that reads 1/1 Running, complains about nothing and serves nobody, and the only evidence of what happened stayed in the previous instance's log (Chapter 8). Step 4 hands you a manifest the cluster rejects because it was written against a catalog page that has already been torn out, and you have to find the current page without changing what the object does (Chapter 8). No check believes what you wrote down: every one of them re-queries the cluster at grading time, one steps inside the container to ask the application itself, another calls the Service from a different Pod, and all of them demand that the probe or the object that was in the way is still in place. Deleting the probe so the symptom shuts up is the shortcut this lab punishes in three of the four steps.

## Prerequisites

- A disposable Linux x86_64 machine with kind, kubectl, docker (reachable without sudo) and base64 on PATH, and at least 4 GB of free RAM. Confirm each tool with its own --version before you start, do not trust this prose. Verified on 2026-10-09 with kind v0.33.0, kubectl v1.37.0 and Docker 29.9.0.
- ISOLATION, and this one is not optional. The lab creates its own single-node kind cluster called ckad-p03 and writes its kubeconfig into a PRIVATE file, ~/ckad-lab/p03/kubeconfig, from the very first command. Every kubectl command in this lab carries --kubeconfig pointing at that file, and you must do the same. Never rely on the current context of your ~/.kube/config: if you have another cluster open, a kubectl delete without --kubeconfig lands on that one and not on this one. The lab touches no other cluster, context or container on your machine.
- IMAGES PINNED BY DIGEST, verified on 2026-10-09. The cluster node: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, pinned on purpose: kind v0.33.0 defaults to a different node image, and the lab passes this one with --image so it does not depend on the kind version you have. The applications in all four steps: busybox@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 (BusyBox v1.37.0), which ships the httpd server they serve with. The mandadero client Pod, the telephone the Services are called from: curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17. A tag is mutable and a digest is not: the chapters teach you to look up the current version, the lab pins it so the exercise is reproducible.
- Internet egress during setup, to pull the three pinned images. Grading itself needs no internet, only the live cluster: the checks query the API server and call the Services from inside the cluster itself.
- Setup takes about a minute and a half and hands the cluster back ALREADY BROKEN, on purpose. Before applying the faults it measures three things and stops with a named error if any of them fails: that the API server no longer serves batch/v1beta1, that the kubelet genuinely restarts a container when its liveness probe fails, and that an unready Pod is genuinely kept out of the Service's directory. If you want to restart a step from scratch, run the full teardown and run setup again: the faults are applied during setup, not step by step. Teardown deletes exactly the ckad-p03 cluster and the ~/ckad-lab/p03 directory, nothing else.
- Having read Chapters 7 and 8. This lab does not re-explain what each probe does, why a ready Pod is different from a running Pod, how to read a container's previous-instance log, or what it means for an API version to stop being served; it makes you operate all four against a real cluster that is already sick.
- One warning about Step 3, and read it before you start: that step's evidence lives in the previous container's log, and that log leaves with the Pod. If you fix first and ask questions later, the Deployment replaces the Pod, the complaint disappears, and you will have to run teardown and setup again to get it back. Read before you prescribe.

## Steps

The `0N-step.sh` is there so you never get stuck: read the step, try it on your own first, and run the script when you want to compare. It also writes the answer file the step asks for, reading the values from the live cluster.

### 1. Ch. 7: The oven the boss orders switched off every fifteen seconds (10 pts)

The neighborhood bakery hired a new manager and the business broke the same day. The oven is fine, the bread comes out, the counter serves. But the manager has a habit: every few seconds he calls the oven's extension to confirm it is still alive, and since nobody picks up, he orders it switched off and back on. The oven has spent the whole morning turning on and off and nobody has eaten any bread.

The oven is not broken. What is written down wrong is the extension number. That is exactly a misaimed `livenessProbe`, and Chapter 7 was clear about what it means: a liveness probe does not ask whether the application is ready, it asks whether it is still alive, and when it decides that it is not, the kubelet does not warn you and does not negotiate, it kills the container and starts it again.

Start with the thermometer, which is `kubectl get pods`, and look at the RESTARTS column: if that number climbs on its own while you watch, you already know somebody is killing the container on purpose. Then go to the medical history, which is `kubectl describe pod`, and scroll down to the events. There the kubelet writes down, by name, which address and which port it called and what it was told. Compare that port with the one the container actually declares and you have the full diagnosis.

And now the temptation, which in this step takes two seconds: delete the `livenessProbe` and the restarts stop. They really stop, the row goes 1/1 Running, it looks perfect. And you have just taken the pulse off the business so the alarm would stop ringing. The check demands that the probe is still in place, that it is still an HTTP check and that it points at the port the application genuinely serves, and on top of that it steps into the Pod to confirm it with its own hands.

DELIVERABLE: the `horno` Deployment at 1/1 with its liveness probe still in place and no longer restarting, and the file `~/ckad-lab/p03/01-respuesta.txt`, exactly 3 lines:

```text
PUERTO_SONDA=<the port the liveness probe was calling>
PUERTO_REAL=<the port the container declares and genuinely serves>
RAZON_EVENTO=<the reason Kubernetes wrote into the warning event, verbatim, a single word>
```

<details>
<summary>What you should see</summary>

Before you fix anything, kubectl get pods shows a single Pod with the RESTARTS column climbing every few seconds: at first it reads 1/1 Running with 1 or 2 restarts, and two or three minutes later it reads 0/1 CrashLoopBackOff with five or six, because the kubelet has had enough of retrying that fast. Both states are the same fault at two different moments. In the events there is a Warning line with reason Unhealthy and the message 'Liveness probe failed: Get "http://<Pod-IP>:8081/": dial tcp <Pod-IP>:8081: connect: connection refused', followed by a Normal line with reason Killing saying the container failed its liveness probe and will be restarted. The manifest declares exactly one container port, named http, on 8080. After the fix the Pod sits at 1/1 Running and the restart counter stops moving: if you look, wait forty five seconds and look again, the number is the same.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 2. Ch. 7: The counter that serves but never raises the OPEN sign (10 pts)

There are two employees behind the counter at the corner shop, both of them showed up, both of them are standing there, and they have gone the whole morning without receiving a single delivery order. The owner swears the delivery dispatcher has him blocked. The dispatcher swears the shop shows as closed.

They are both right, and that is Chapter 7's lesson. An application can be running perfectly and still not be READY, and in Kubernetes that is not an opinion, it is a switch: until the `readinessProbe` passes, the Pod does not enter the Service's directory, and if it is not in the directory, not one single customer reaches it. The container does not die, does not restart, does not complain. Nobody simply ever calls it.

Look at the READY column of `kubectl get pods`: two Pods at `0/1 Running`, with zero restarts. That already tells you this is not the same as Step 1: nobody is killing anything here. Then look at the directory, which is the Service's EndpointSlice, and look carefully, because this is the part people skip: the directory is NOT empty. It carries both addresses, each with a condition saying whether that address is ready or not. An empty directory would be a selector problem; a directory with unready addresses is a readiness problem. Now you know which way to go.

So read what the probe is asking the application, and ask the application the same question yourself, by hand, from the `mandadero` Pod. You will see the application answers perfectly well, and that what does not exist is what it is being asked for. The OPEN sign never goes up because the boss asked for it to go up only when somebody answers at a window that was never built.

And the usual temptation: delete the `readinessProbe` and both addresses enter the directory immediately, because a Pod with no readiness probe is taken as ready the moment it starts. The deliveries start arriving. And you have just started sending customers to a counter without ever checking again whether anybody is serving. The check demands the probe is still in place and still HTTP against the same port.

DELIVERABLE: the `mostrador` Deployment at 2/2, both addresses ready in the EndpointSlice, a curl from the `mandadero` Pod returning 200 against `http://domicilios.la-tienda.svc.cluster.local/` with the probe still in place, and the file `~/ckad-lab/p03/02-respuesta.txt`, exactly 3 lines:

```text
RUTA_SONDA=<the HTTP path the probe was asking for and that the application does not serve>
CODIGO_HTTP=<the status code the application answered that path with>
TIPO_DE_SONDA=<the field name of the guilty probe, exactly as it is written in the manifest>
```

<details>
<summary>What you should see</summary>

Before you fix anything, kubectl get pods shows both Pods at 0/1 Running, with not a single restart: nobody is killing them, they simply never become ready. The Deployment shows READY 0/2. The domicilios Service's EndpointSlice carries both IP addresses, but both with the ready condition set to false, which is why a call to the Service name falls over with code 000 and curl exits with status 7, meaning 'could not connect'. There is a detail here worth the whole step: the directory is NOT empty. An empty directory would mean the selector finds nobody; a directory full of unready addresses means the selector is fine and the problem is readiness. In the events you get reason Unhealthy with the message 'Readiness probe failed: HTTP probe failed with statuscode: 404'. A manual curl against the path the probe asks for returns 404, and against the root it returns 200. After the fix the Deployment sits at 2/2 and the call to the Service name returns 200. Right as the rollout finishes, the EndpointSlice may still list the two old addresses as false while their Pods terminate, next to the two new ones as true; a few seconds later only the two new ones remain.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 3. Ch. 8: The complaint that was only written in last round's book (10 pts)

This is the most uncomfortable case of them all, because the system is not warning you about anything. The Pod says `1/1 Running`. The probe does not fail, because nobody gave it a probe. The Deployment is complete. The dashboard is green. And the catalog does not open.

Chapter 8 called this the customer who will not say what happened, and it left you the order in which to get the truth out of them. The first thing is to accept that the table holds exactly ONE clue, and it is the RESTARTS column: if it says 1, that application started, died and started again. Something happened, and it happened once.

The second thing is to open today's complaints book, which is `kubectl logs`. And here comes the surprise: it is blank. Not one line. That does not mean nothing happened, it means the instance running NOW has nothing to say. The complaint was written by the previous instance, the one that died, and that log still exists but is not read with the same command: it is read with `--previous`. That is the tool this step is charging you for.

And now the most important warning in the whole lab, and it is serious: that log leaves with the Pod. The moment you fix the Deployment and the rollout replaces the Pod, the complaint disappears forever and no command brings it back. Read first, write it down, then prescribe. If you already lost it, run teardown and setup again; it is no drama, it takes ninety seconds.

When you read the message you will understand why the system never warned you: somebody asked for a piece of data that does not exist and on top of that marked that data as not mattering if it was missing. Kubernetes took them at their word: it did not block the start, it left the variable empty and carried on. That little field is what turned a configuration error, which would have been visible immediately in the Pod's status, into a silent failure that only shows up in last round's book.

Fix it by reading the data from where it belongs. The catalog page is read off the inventory, not memorized: if you delete the `valueFrom` and type the value in by hand, the catalog opens, the number comes out right, and you fixed nothing. The check will notice.

DELIVERABLE: the `catalogo` Deployment at 1/1 serving the page the ConfigMap says, with the variable still read from the ConfigMap, and the file `~/ckad-lab/p03/03-respuesta.txt`, exactly 3 lines:

```text
MENSAJE_FATAL=<the complete line the previous instance left written, verbatim, without quotes>
LLAVE_FANTASMA=<the exact name of the key the manifest asked for and that the ConfigMap does not have>
CAMPO_QUE_LO_TAPO=<the name of the manifest field that made the container start anyway instead of failing outright>
```

<details>
<summary>What you should see</summary>

Before you fix anything, kubectl get pods shows a single Pod at 1/1 Running with exactly 1 restart, and that 1 is the only clue the table gives you: the Pod looks healthy. A call to the Service returns code 000 and curl exits with status 7, because there is nothing listening inside the container. kubectl logs against that Pod prints absolutely nothing, not one line. kubectl logs with --previous prints exactly one line: 'FATAL: PAGINA_CATALOGO vacia, el catalogo no abre'. The manifest asks for the PAGINA_CATALOGO variable with a configMapKeyRef pointing at the el-inventario ConfigMap and the PAGINA_VIEJA key, with optional set to true; the el-inventario ConfigMap exists and has exactly one key, PAGINA_CATALOGO, holding the value edicion-2026-08. That optional set to true is the reason the Pod started at all instead of sitting in CreateContainerConfigError: it told Kubernetes to carry on even though the key was missing. After the fix the new Pod sits at 1/1 Running with 0 restarts and the curl to the Service returns the body 'catalogo edicion-2026-08'. The first attempt may exit with status 7 if the new Pod has not yet joined the Service's directory; that is why the command retries every five seconds.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 4. Ch. 8: The catalog that changed page and nobody told the warehouse (10 pts)

The warehouse has an inventory count that has run by itself every minute for years, and this week they moved it onto the new cluster and it never started. The supervisor says "the file is the same as always" and he is entirely right: the file is the same. What changed is the hardware store's catalog.

Chapter 8 said it in those words: an API version is a page in a catalog, and pages get pulled. They are not pulled overnight or in secret, they are announced years in advance, marked as deprecated, and in one specific version they stop being served. The object you submitted is not badly written: it is written against a page that has already been torn out of the catalog.

Setup already tried to apply that manifest for you and saved the verbatim rejection into `~/ckad-lab/p03/inventario/apply-fallido.log`. Read it in full, including the second line, and distrust that one: it will suggest CRDs are missing. No CRD is missing here. That line is the generic message the client prints whenever it cannot find the object type, and it is a classic red herring.

Now the part this step is really charging you for: do not guess which page is the good one, ask the cluster. `kubectl api-resources` tells you, for each object type, which version THAT cluster serves today, and `kubectl explain` confirms the shape of the object. Reading the live catalog of the cluster in front of you is worth far more than remembering what the catalog said last year. For the deliverable's third line you do have to go to the official documentation: Kubernetes publishes a guide to removed API versions that states, resource by resource, from which version each one stopped being served.

And the warning: here the temptation is not to delete a probe, it is to "fix" it by changing what the object does. Turning it into a standalone Job that runs once, changing the schedule so it stops bothering anybody, or leaving it suspended. All three make the error disappear from the screen and leave the inventory uncounted. The check looks for the most recent job that finished successfully, confirms that CronJob created it, and reads its logs to see whether the count genuinely happened.

DELIVERABLE: the `conteo-inventario` CronJob alive in the `el-deposito` namespace, with the same name, the same schedule and the same command, and with at least one of its Jobs completed successfully; plus the file `~/ckad-lab/p03/04-respuesta.txt`, exactly 3 lines:

```text
APIVERSION_MUERTA=<the API version the manifest was written against>
APIVERSION_VIVA=<the API version this cluster serves today for that resource>
VERSION_QUE_LA_RETIRO=<the Kubernetes version from which that API version stopped being served, written as vX.YY>
```

<details>
<summary>What you should see</summary>

The apply-fallido.log file from setup carries the verbatim rejection: 'error: resource mapping not found for name: "conteo-inventario" namespace: "el-deposito" from ...: no matches for kind "CronJob" in version "batch/v1beta1"', followed by the line 'ensure CRDs are installed first'. That second line is a friendly red herring: no CRD is missing here, what is missing is the catalog page. kubectl -n el-deposito get cronjobs answers 'No resources found in el-deposito namespace.', because the object never got created. kubectl api-resources --api-group=batch shows two rows, cronjobs and jobs, both with APIVERSION batch/v1 and neither with batch/v1beta1: that is this cluster's current catalog, read off the cluster itself and not off memory. After changing only the apiVersion line, the apply answers 'cronjob.batch/conteo-inventario created'. With the every-minute schedule, in under sixty seconds a Job appears with COMPLETIONS 1/1 and STATUS Complete, and its logs carry a line starting with 'conteo terminado:' followed by a timestamp.

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

- **Symptom (step 1):** The Pod shows 0/1 CrashLoopBackOff instead of 1/1 Running; it looks like a different fault
  **What to do:** It is the same fault later on. The kubelet restarts the container every time the liveness probe fails, and once it has done that several times in a row it stops retrying immediately and starts waiting longer and longer between attempts: that is what shows up as CrashLoopBackOff. The useful clue is not the word in STATUS but the number in the RESTARTS column and the event with reason Unhealthy, both of which are there either way. Fix the port and the Pod leaves the back-off on its own.

- **Symptom (step 1):** I already corrected the port and the check sits silent for almost a minute before answering
  **What to do:** That is on purpose. A restart counter standing still can only be proven by looking at it twice with time in between, so the check reads it, waits forty five seconds and reads it again. Wait for the rollout to finish before grading, with kubectl rollout status deployment/horno, because if you grade in the middle of the update the Pod the check picks may be the old one.

- **Symptom (step 2):** kubectl get endpoints shows me an empty ENDPOINTS column, but kubectl get endpointslices shows me two addresses. Which of the two is lying to me?
  **What to do:** Neither. They are two views of the same fact: the EndpointSlice lists ALL the addresses the selector found and gives each one a ready condition saying whether it is ready; the older Endpoints view only shows the ready ones. That is why one looks empty and the other does not. The column that actually helps you diagnose is the EndpointSlice's ready condition, which is what separates 'I found nobody' from 'I found them and none is ready'.

- **Symptom (step 2):** I changed the probe and the curl from mandadero keeps failing for a few seconds
  **What to do:** Let the full rollout finish plus a few more seconds. The Deployment replaces the Pods one at a time, each new Pod has to pass its probe before entering the directory, and the directory takes a moment to propagate. Use kubectl rollout status deployment/mostrador to wait instead of repeating the curl, and confirm with the EndpointSlice's ready condition before calling again. The check already retries the curl several times for exactly this reason.

- **Symptom (step 3):** kubectl logs --previous answers 'previous terminated container not found'
  **What to do:** That means that Pod has no previous instance, and almost always it means you are asking a brand new Pod: if you already changed the Deployment, the Pod you are looking at was born after the fix and never died. The old log left with the old Pod and cannot be recovered. Run teardown and setup again and this time read before you touch. Always confirm you are asking the right Pod by looking at the RESTARTS column: if it says 0, there is nothing previous to read.

- **Symptom (step 3):** The check rejects my MENSAJE_FATAL line even though I copied the text
  **What to do:** The line is compared whole and exact, so check three things: that you did not leave a trailing space, that you did not wrap the message in quotes, and that you copied the entire line including the word FATAL and the colon. The format is MENSAJE_FATAL= followed immediately by the text exactly as the container printed it, and nothing else. Copy and paste from the kubectl output instead of typing it out by hand.

- **Symptom (step 4):** I applied the corrected manifest and kubectl -n el-deposito get jobs shows nothing
  **What to do:** A CronJob does not run at the moment you create it, it runs when the schedule fires. With an every-minute schedule you may have to wait up to sixty seconds to see the first Job, and a few more for it to finish. Look at the LAST SCHEDULE column of kubectl get cronjob: while it is empty, it has not fired yet. If it still has not fired after two minutes, confirm the SUSPEND column says False.

- **Symptom (step 4):** The error says 'ensure CRDs are installed first' and I went looking for which CRD to install
  **What to do:** That line is generic: kubectl prints it whenever it cannot resolve a kind against any served version, whatever the cause, and the most frequent cause is not a missing CRD but a removed API version. The way to decide which of the two it is, in ten seconds, is kubectl api-resources: if the kind shows up there with a different APIVERSION, the problem is the version and not a CRD; if it does not show up anywhere, then it would be fair to start wondering about a missing extension.

## Going further

- Go back to Step 1 and break the oven the other way around: leave the liveness probe aimed correctly and give a slow-starting application a startupProbe with a very short budget, for instance a container that sleeps forty seconds before bringing up httpd. Predict in writing, before applying anything, whether the event you will see says Liveness or Startup, and then check. That is the difference between a sick application and an application that simply has not finished opening yet.
- In Step 2, instead of correcting the probe's path, take the other valid route: leave the probe asking for /abierto and make the application genuinely serve that path. Both fixes respect the control and both pass the check. Write three lines on which one you would prefer in production and why, and in particular on what happens the day somebody changes the application without knowing a probe is watching that path.
- In Step 3, put the lab into the state it should have been in from the start: add an HTTP readinessProbe against 8080 to the catalogo Deployment. Then break it again by pointing the variable at a key that does not exist and watch the difference. With a probe, the Pod never becomes ready and the Service never publishes it; with no probe, the Pod looks green and the client crashes into it. That contrast is the whole of Chapter 7 in a single experiment.
- In Step 4, do the reverse exercise, which is the more useful one in real life: find in the official removed-versions guide another resource that also changed page, write a manifest against the old version, apply it on this same cluster and compare the rejection with the one you already know. Then correct it. Two cases are enough for the pattern to stop surprising you.

## References

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
