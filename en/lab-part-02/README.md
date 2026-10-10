# Part II - Lab: changing the shift without ever dropping below four servers, going back to the menu from two days ago instead of yesterday's, serving the new dish to one customer in five, and opening the franchise from the assembly manual at the version you were promised

- Time: 55 min
- Points: 40

## Objective

This is an Exam-Style lab: each step gives you only the objective and the end state that gets graded, and that step's exact command sequence lives in its cmd field for you to reveal after you have tried on your own first. Step 1 hands you a business constraint written in numbers (at peak hour there can never be fewer than four stations serving, and the kitchen holds no more than five cooks at once) and asks you to tune maxSurge and maxUnavailable so the rolling update honors it; grading does not compare strings, it converts what you wrote into a number of Pods and demands that number satisfy the constraint, so the whole-number form and the percentage form both count as long as they really comply (Chapter 4). Step 2 has you build three revisions and then walk back with kubectl rollout undo to a specific revision rather than the previous one, and grades the end state of the revision annotation, which is exactly where intuition fails: the number does not go down, it goes up, and the revision you rolled back to disappears from the history because Kubernetes renumbers its ReplicaSet (Chapter 4). Step 3 has you build a real canary, two separate Deployments sharing a single Service, at a stated eight-to-two ratio, and the check does not trust the declared replicas: it counts the Service's live endpoints one by one, cross-references each against the version label of the Pod that owns it, and then stands up its own probe firing a hundred requests to confirm the Service really does split across both versions (Chapter 5). Step 4 has you deploy an application with Helm pinning the chart version, and the check inspects all three layers: that a Helm release record exists at that exact version, that the values you passed live in the release and not only in the cluster, and that the running application reports the version and the message you configured out of its own mouth (Chapter 6). No check reads your command history: every one of them re-queries the cluster, and two of them create fresh probes and delete them to confirm the substrate really does what the lab assumes.

## Prerequisites

- A Linux machine with kind, kubectl, helm and Docker on PATH, and at least 4 GB of free RAM. This lab brings up its OWN three-node kind cluster named ckad-p02 and writes its kubeconfig to a private file, ~/ckad-lab/p02/kubeconfig, which is not your everyday one. It never touches ~/.kube/config, your current context, or any other cluster you already have running. That is why EVERY command in this lab carries --kubeconfig; forget the flag once and kubectl points at a different cluster without telling you.
- Helm is isolated too. Step 4 exports HELM_CONFIG_HOME, HELM_CACHE_HOME, HELM_DATA_HOME, HELM_REPOSITORY_CONFIG and HELM_REPOSITORY_CACHE into ~/ckad-lab/p02/helm, so the chart repository you add here does not land in whatever helm configuration you already have on your machine. If you open a fresh terminal halfway through Step 4, export those five variables again before continuing.
- Three nodes, not one. The cluster is created from a kind config file declaring one control-plane and two workers, because Step 1 needs the four replicas spread out for the rolling update to mean anything, and Step 3 stands up ten Pods that have to fit somewhere.
- Internet access when you set the lab up and during Step 4: kind pulls the node image, the Pods pull the three digest-pinned nginx images, and helm downloads the chart from its public repository. Grading Steps 1, 2 and 3 needs no internet; nor does Step 4, because by then the chart is already installed, but it does need the helm binary still on PATH.
- PINNED VERSIONS, verified on 2026-10-09 on this same machine. kind v0.33.0, kubectl v1.37.0 and helm v4.3.0 (the lab only uses helm subcommands that have existed since the 3.13 series, so a recent helm 3 works too). Node image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, declared explicitly in the config file so it does not depend on whichever kind you happen to have. Confirm what actually got installed with kind version, kubectl version --client and helm version, never from memory, and confirm your nodes' real version with kubectl get nodes.
- THREE container images pinned by digest, verified on 2026-10-09 against Docker Hub from this machine. The old one, nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10; the middle one, nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236; and the new one, nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de. Three, because Step 2 needs three revisions built up so you can walk back to the middle one, which is where the lesson lives. A tag is mutable, a digest is not, which is why the checks compare the full string with the digest and not the bare tag. They also give themselves away through nginx's Server header, and Step 3 uses that header as proof the Service really does split traffic.
- ONE Helm chart pinned by version, verified on 2026-10-09: podinfo 6.13.0, from the public repository https://stefanprodan.github.io/podinfo. A version that is NOT the latest was chosen on purpose: on the verification date the latest was 6.15.0, so a helm install without --version brings you something else and the step fails. That is exactly Chapter 6's lesson.
- Having read Chapters 4, 5 and 6. This lab does not re-explain what a ReplicaSet is, the difference between blue-green and canary, or what a chart is; it makes you operate all four against a real cluster and grades you on the end state.

## Steps

The `0N-step.sh` is there so you never get stuck: read the step, try it on your own first, and run the script when you want to compare. It also writes the answer file the step asks for, reading the values from the live cluster.

### 1. Ch. 4: Changing the shift with the owner's constraint written down in numbers (10 pts)

Chapter 4 left the shop open and the lesson in place: you do not close to change the shift. Here's what's actually going on: on the exam nobody is ever going to tell you "set maxSurge to 1". They are going to give you a business constraint, in numbers, and you have to translate it. That translation is the step.

The owner's constraint, verbatim: at peak hour there can NEVER be fewer than FOUR stations serving, and the kitchen holds NO more than FIVE cooks at once. The Deployment has four replicas. Sit with that for five seconds before writing anything. If there can never be fewer than four serving and you have four, then how many may be down at once. And if no more than five fit in total, how many extra may you create while replacing.

And here is the mistake made in a hurry: leaving the strategy as it ships. Kubernetes ships 25% and 25%, and over four replicas that 25% unavailable means you are permitted to leave ONE station empty. The rollout will finish fine, everything will look green, and you have just violated the constraint they wrote for you. A rollout that finishes is not a rollout that complies.

And there is one thing worth watching while it runs, because it is the only visible proof the constraint is being honored: the rollout status narration. With unavailable at zero, the controller creates the new Pod first, waits for it to be Ready, and ONLY then kills an old one. That is why you will read "1 out of 4", "2 out of 4", "3 out of 4" and only at the end "1 old replicas are pending termination". Had you loosened the constraint, that narration would read differently.

DELIVERABLE: the turno-de-almuerzo Deployment running in the el-restaurante namespace on the new image, its four replicas Ready, and a strategy that satisfies the constraint; and the file `~/ckad-lab/p02/01-respuesta.txt`, exactly 3 lines:

```text
MAX_SURGE=<what the Deployment's .spec.strategy.rollingUpdate.maxSurge says now, exactly as it got stored>
MAX_UNAVAILABLE=<what the Deployment's .spec.strategy.rollingUpdate.maxUnavailable says now, exactly as it got stored>
REPLICAS_LISTAS=<what .status.readyReplicas says now>
```

<details>
<summary>What you should see</summary>

When you create the Deployment, the strategy query answers tipo=RollingUpdate, surge=1 and nodisp=0, which is what you wrote stored verbatim in the object. When you change the image, rollout status narrates the replacement in a very particular way worth stopping to read: it says 1 out of 4 new replicas have been updated, then 2 out of 4, then 3 out of 4, and only at the end does it say 1 old replicas are pending termination. It never says fewer than four are available, because with maxUnavailable at 0 the controller creates the new Pod first, waits for it to be Ready, and only then kills an old one. When it finishes, listas, actualizadas and disponibles all say 4, 4 and 4, the live image ends in the 56168782 digest, and the ReplicaSet listing shows two objects: the middle image at revision 1 with DESEADAS at 0, and the new image at revision 2 with DESEADAS at 4.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 2. Ch. 4: Going back to the menu from two days ago, and finding the revision number goes up instead of down (10 pts)

Chapter 4 said that walking things back is part of the trade. Here's what's actually going on: almost everyone practices the easy rollback, the one step backwards, and the day the bad menu has two changes stacked on top of it they sit there staring at the screen. This step is the hard one on purpose.

You are going to build three revisions: the old menu, the middle menu, the new menu. And the customers are not complaining about the new one alone but about the last two: you have to go back to the MIDDLE one, not to the previous one. That is no longer a bare rollout undo, that is rollout undo aimed at a specific revision.

And here is the part that stings the first time, so let me say it up front: when you roll back to revision 2, the Deployment's revision annotation does NOT end up at 2. It ends up at 4. A revision number is not a position in a list you return to, it is a counter that only goes up, and rolling back counts as a change too. Stranger still: when you look at rollout history again, the revision 2 row is gone. You will see 1, 3 and 4.

Do not panic and above all do not go do something else on top of it. Nothing was lost. Kubernetes did not copy or recreate the old ReplicaSet: it took the very same one, the one already holding the middle image, and changed its annotation from 2 to 4, because it is exactly the same set of Pods. Revision 2 was not deleted, it was renamed. If you look at the three ReplicaSets with their numbers beside them, the whole story is there and it adds up.

And a note of honesty, because this lab grades end state and not path: if instead of rollout undo --to-revision=2 you simply set image back to the middle image, you land in EXACTLY the same place, revision 4 included. Both paths pass. Both were verified.

DELIVERABLE: the carta-de-la-semana Deployment running in el-restaurante on the middle image with its three replicas Ready, and the file `~/ckad-lab/p02/02-respuesta.txt`, exactly 3 lines:

```text
REVISION_FINAL=<what the Deployment's `deployment.kubernetes.io/revision` annotation says now>
IMAGEN_VIVA=<the full image string running now, tag and digest>
REVISIONES_VIVAS=<the revision numbers of the ReplicaSets that exist now, lowest to highest, comma separated with no spaces, for example 1,3,4>
```

<details>
<summary>What you should see</summary>

Before the undo, rollout history lists THREE clean rows: 1, 2 and 3. After undoing to revision 2, the Deployment's annotation does NOT say 2: it says 4. The live image is the middle one again, the one ending in the a8b39bd9 digest, and listas says 3. And here is what you have to see with your own eyes because you never forget it afterwards: rollout history AFTER the undo lists 1, 3 and 4. Revision 2 vanished from the history. Nothing was deleted and nothing was lost: Kubernetes reused that same old ReplicaSet, the one carrying the middle image, and changed its revision annotation from 2 to 4, because it is literally the same set of Pods you rolled back to. That is why the ReplicaSet listing shows three objects, at revisions 1, 3 and 4, and the only one with DESEADAS at 3 is the one at revision 4.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 3. Ch. 5: The new dish for one customer in five, with a single cash register (10 pts)

Chapter 5 told you the difference between blue-green and canary, and this step has you build the canary, which is the one asked about most and understood worst.

Here's what's actually going on: people picture a canary as something very sophisticated, with configurable percentages and a control panel. In plain Kubernetes there is none of that. A canary is Pod arithmetic and a single cash register. You stand up TWO separate Deployments, each with its own image, and you give both of them the SAME shared label. Then you stand up ONE Service whose selector names only that shared label and does NOT name the version. That is all. The Service pools the Pods of both Deployments into one bag of endpoints and kube-proxy picks at random among them. Nobody configures the ratio: it falls out of each side's replica count.

The owner's order: one customer in five tries the new dish, and there must be ten stations serving in the room in total. Do the arithmetic before you write the YAML.

And here is the confusion to kill: the version label DOES go on the Pods, and it DOES go in each Deployment's selector, but it does NOT go in the Service's selector. Those are three different things that get written similarly. The Deployment's selector has to tell the two versions apart, because otherwise each Deployment would adopt the other's Pods and they would fight over the replica count. The Service's selector has to NOT tell them apart, because that is the whole trick. Copy the same selector into both places and you have built either two services or a fight.

And do not stop at the theory: at the end of the step stand up a probe inside the cluster and ask the Service for the page a hundred times. The two nginx versions give themselves away in the Server header, and you will watch with your own eyes as the same address answers 1.28 sometimes and 1.29 other times. That is the canary working, and it is the same thing the check does when it grades you.

DELIVERABLE: the el-restaurante Service and both Deployments running in the la-plaza namespace, at the ratio the owner asked for, and the file `~/ckad-lab/p02/03-respuesta.txt`, exactly 3 lines:

```text
ENDPOINTS_TOTALES=<how many ready endpoints the el-restaurante Service has now>
ENDPOINTS_NUEVO=<how many of those endpoints are Pods of the new version>
PORCENTAJE_NUEVO=<what percentage of the total the canary represents, whole number without the percent sign>
```

<details>
<summary>What you should see</summary>

The Service's selector comes out as `{"app":"menu"}` and nothing else: it does not name the version, and that is the whole mechanics of a canary. The endpointslices query lists TEN Pod names, eight starting with sabor-de-siempre and two starting with sabor-nuevo, all of them ready targets of the same Service. The Pod table confirms each one's version label. And the probe is the part that convinces: a hundred requests to the same name http://el-restaurante/ come back with TWO different Server headers, nginx/1.28.3 and nginx/1.29.8, split roughly eighty to twenty. They will not come out exactly 80 and 20, because kube-proxy picks at random on every new connection; in a run on 2026-10-09 they came out 82 and 18. What matters is not the exact number but that both versions show up.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 4. Ch. 6: Opening the franchise from the assembly manual, at the version you were promised and not the latest one released (10 pts)

Chapter 6 compared a chart to a franchise assembly manual: you do not reinvent the storefront, the manual arrives with everything inside and you only adjust what is local. This step has you open the branch for real.

Here's what's actually going on: almost everyone learns Helm by typing helm install and stopping there, and that command brings whatever is LATEST in the repository that day. It works today. Tomorrow a new chart version ships, the same command brings something else, and your production environment and your colleague's are no longer the same environment even though both of you ran the same command. That is why this step asks you to pin the chart version, and asks you to pin one that is NOT the latest, so you notice.

And there are three layers you have to learn to keep apart, because the exam mixes them on purpose.

The first is the release RECORD. Helm has no server and no database: it stores each release in a Secret inside the namespace itself, named sh.helm.release.v1.<release>.<number>. If that Secret does not exist, there is no release, however many Pods are running.

The second is the VALUES. The values you pass with --set do not stay in the Deployment, they are stored in the release. And that is where the most expensive mistake of all comes from.

Listen carefully: if you are asked for three replicas and you get there with kubectl scale, the live Deployment will say 3 and the release will still say 1. It looks perfect. And the day somebody runs a routine helm upgrade, touching nothing related, the release wins and puts the number back to 1 in front of everyone. What you scale in a release, you scale through the chart value, not from outside it.

The third layer is the RUNNING application, which is the only one that cannot be faked. So at the end you will stand up a probe inside the cluster and ask the application who it is. And the application will answer with JSON carrying its own version and the message you configured. That closes the circle: manual pinned, values set, business open.

DELIVERABLE: the franquicia-del-barrio release installed with Helm in the la-franquicia namespace, from the pinned chart, with three replicas and the message `lo que pasa es que aqui si atienden` set as chart values, and the file `~/ckad-lab/p02/04-respuesta.txt`, exactly 3 lines:

```text
VERSION_DEL_CHART=<the chart version Helm reports for this release, just the number>
MENSAJE_VIVO=<the message the running application returns in its JSON, verbatim>
REPLICAS_LISTAS=<the ready replicas of the Deployment the chart installed>
```

<details>
<summary>What you should see</summary>

helm search repo shows you that the chart's latest version is NOT 6.13.0 (on the verification date the latest was 6.15.0), and that is exactly why you pin. helm show chart with --version 6.13.0 answers name: podinfo, version: 6.13.0 and appVersion: 6.13.0. The install ends saying STATUS: deployed and REVISION: 1. helm list in JSON carries "chart":"podinfo-6.13.0" and "app_version":"6.13.0". helm get values returns exactly what you passed and nothing else, {"replicaCount":3,"ui":{"message":"lo que pasa es que aqui si atienden"}}, because get values shows the values you laid on top, not the chart's complete values file. The Secret listing shows one object named sh.helm.release.v1.franquicia-del-barrio.v1 with ESTADO deployed, which is where Helm really keeps the release record; there is no separate database. The Deployment runs on image ghcr.io/stefanprodan/podinfo:6.13.0 with three replicas Ready. And the probe closes the circle: the application answers with JSON in which it reports, of its own accord, "version": "6.13.0" and "message": "lo que pasa es que aqui si atienden".

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

- **Symptom (step 1):** The rollout hangs and never finishes, with maxUnavailable at 0
  **What to do:** With maxUnavailable at 0 the controller does NOT kill anyone until the new Pod is Ready, so if the new Pod will not start, the rollout sits there forever instead of tearing your service down. That is correct behavior, not a bug. Look at why it will not start with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get pods; if it is Pending and the cluster already carries Step 3's Pods, the fifth Pod may not fit, and the answer there is to finish Step 1 before building Step 3, not to loosen the constraint.

- **Symptom (step 1):** The API server rejects the Deployment saying maxSurge and maxUnavailable may not both be zero
  **What to do:** That is true and it is deliberate: if nobody may be missing and no extra may be created either, there is physically no way to replace anything. That is why the owner's constraint gives you room on one side (five fit, four exist) even while taking it away on the other. If you hit that error, you set both to zero; re-read the constraint and split them.

- **Symptom (step 1):** set image replies that it could not find the container you named
  **What to do:** The container's name comes from the Pod template, not from the Deployment. In this step's manifest the container is called nginx, which is why the command says nginx=. Confirm it with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get deployment turno-de-almuerzo -o `jsonpath='{.spec.template.spec.containers[0].name}'` instead of guessing.

- **Symptom (step 2):** rollout history does not show you three revisions, it shows fewer
  **What to do:** A Deployment only keeps as many old revisions as its revisionHistoryLimit field says, and the extras get pruned. Read your own real value with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n el-restaurante get deployment carta-de-la-semana -o `jsonpath='{.spec.revisionHistoryLimit}'` instead of assuming it. If you genuinely ended up with fewer than three, it is because some change never completed its rollout; check that each set image finished with its rollout status before the next one.

- **Symptom (step 2):** The undo replied that revision 2 does not exist
  **What to do:** Almost always two of your three images ended up identical, and then the second set image produced no new revision because the template did not change. Compare the three images' digests line by line before repeating, and confirm how many revisions really exist with rollout history. A Deployment only cuts a new revision when the Pod TEMPLATE changes; changing the replica count, for instance, produces no revision.

- **Symptom (step 3):** One of the two Deployments cannot hold its replicas, they go up and down on their own
  **What to do:** That is the adoption fight, and it happens when BOTH Deployments have the same selector: each controller sees the other's Pods as its own and kills them to balance its count. Each Deployment's selector has to include the version label so they are disjoint. Confirm them with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n la-plaza get deployment -o `jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.selector.matchLabels}{"\n"}{end}'` and check they are not identical.

- **Symptom (step 3):** The probe always returns the same Server header, it never sees the other version
  **What to do:** First rule out the likely thing: count the Service's endpoints with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig -n la-plaza get endpointslices -l kubernetes.io/service-name=el-restaurante -o yaml and see whether the canary's Pods are in there. If they are not, either their labels do not match the Service's selector or their Pods are not Ready yet. If all ten ARE there and still only one version answers, it is not your YAML: it is the substrate's load spreading, which is why the check treats that case as a named substrate error rather than handing you a pass that would mean nothing.

- **Symptom (step 3):** The ten Pods do not fit and some sit in Pending
  **What to do:** Each Pod in this step requests 10m of CPU and 20Mi of memory on purpose, so the ten fit alongside the seven Pods from Steps 1 and 2. If you raised the requests they will not fit. Read what your nodes really offer with kubectl --kubeconfig ~/ckad-lab/p02/kubeconfig get nodes -o `jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}'` before touching anything.

- **Symptom (step 4):** helm install fails saying it cannot find the chart podinfo/podinfo
  **What to do:** The repository is added from the terminal, and this lab keeps it in its own config file inside the workspace. If you opened a fresh terminal, those five HELM_ variables were lost and helm is reading your everyday configuration, where the repository is not. Export them again and run helm repo list to confirm podinfo shows up before installing.

- **Symptom (step 4):** helm install fails saying version 6.13.0 is not available
  **What to do:** The repository index is cached and may be stale. Run helm repo update and then helm search repo podinfo --versions to see the real list of versions your machine knows today, rather than trusting what this text says. If 6.13.0 genuinely is no longer published, pick a version from the listing that is NOT the latest, and use that number consistently in the command and in your answer file: the check compares against the pinned value of 6.13.0, so in that case say so before continuing instead of inventing.

- **Symptom (step 4):** The Deployment sits in ImagePullBackOff pulling the image from ghcr.io
  **What to do:** This chart's image is public and needs no credential, so the problem is almost always a STALE ghcr.io credential saved in your ~/.docker/config.json that the runtime tries to use and the registry rejects. Try a separate Docker config directory, for example by exporting DOCKER_CONFIG to an empty folder inside ~/ckad-lab/p02, and recreate the cluster; the node then pulls the image anonymously.

## Going further

- Go back to Step 1's Deployment and try the opposite constraint: set maxSurge to 0 and maxUnavailable to 1, change the image and keep reading the rollout status narration. You will see the order flipped, kill first and create second, and at some moment there will be only three stations serving. It is the right strategy when the cluster has no room for one extra Pod, and the wrong one when the owner wrote you Step 1's constraint.
- On Step 2's Deployment, set the kubernetes.io/change-cause annotation before each image change (the --record flag has been retired from modern kubectl) and then watch rollout history actually fill the CHANGE-CAUSE column. It is the only way for the history to tell you WHY each revision happened, and in a real incident that is worth more than the number.
- Scale Step 3's canary from two replicas to five and the stable one from eight down to five, without touching the Service or a single field of it, and run the hundred-request probe again. You will watch the ratio move to half and half live. That is exactly what a progressive rollout does under the hood: there is no magic, there is replica arithmetic. Then take it all the way, with the stable at zero, and notice the Service never stopped answering.
- Run helm upgrade on Step 4's release to chart version 6.14.1 with --version, watch helm list raise REVISION to 2 and a second Secret sh.helm.release.v1.franquicia-del-barrio.v2 appear beside the first. Then run helm rollback and observe that Helm does NOT delete the old Secret and does not reuse its number: it creates a revision 3. Compare that behavior with Step 2's rollout undo, where Kubernetes DOES reuse and renumber the ReplicaSet. They are two different revision systems and the exam asks about them separately.
- Render the same chart without installing it, with helm template franquicia-del-barrio podinfo/podinfo --version 6.13.0 --set replicaCount=3, and compare the output against what is live in the cluster. Then do the same with Kustomize: build a base from Step 1's Deployment and two overlays, one raising the replicas and one changing the image, and render with kubectl kustomize. Both solve the same problem, templates versus patches, and Chapter 6 explains when each one is worth it.

## References

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
