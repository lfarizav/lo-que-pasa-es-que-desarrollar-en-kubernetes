# Part V - Lab: the delivery that really does find the address, the ice cream shop that changed branch and nobody updated the order, a shop that opens only for the courier with a badge, and a directory at the entrance that sends everyone to the right store

- Time: 45-60 min
- Points: 40

## Objective

This is an Exam-Style lab: each step states only the objective, and that step's exact command sequence lives in its cmd field for you to reveal after you have tried on your own first. Step 1 has you expose a Deployment with a ClusterIP Service and prove two different things that almost everybody conflates: that the EndpointSlice filled with the live Pod addresses, and that a client Pod resolves the Service's fully qualified name through cluster DNS and actually gets an HTTP answer over that name (Chapter 13). Step 2 hands you a Service the setup shipped deliberately broken, base64-encoded so you cannot read it at a glance: it has no endpoints at all and you have to diagnose why. Here, unlike in other labs, you are allowed to repair it from either side, and the brief tells you plainly which end state is graded. Step 3 is what separates this lab from a blog post: you first measure that traffic between Pods passes unrestricted, then apply a default deny plus a rule that opens exactly one door by label, and prove with exit codes that the courier with a badge gets in while the street vendor waits (Chapter 15). Step 4 closes on the main entrance: an Ingress with two paths to two different Services, verified with real curls travelling through the controller (Chapter 14). No check reads your history: every one of them re-queries the cluster and three of them generate fresh traffic at grading time.

## Prerequisites

- A Linux machine with kind, kubectl, docker, curl and base64 on PATH, and at least 4 GB of free RAM. The lab creates its own kind cluster named ckad-p05 and writes its kubeconfig to a private file, ~/ckad-lab/p05/kubeconfig, which is not your usual one. Every command passes --kubeconfig pointing at that file, so your ~/.kube/config is never modified and no other cluster of yours is touched. The teardown deletes only the ckad-p05 cluster and the ~/ckad-lab/p05 folder.
- Host ports 8085 and 8543 free. The cluster is created with extraPortMappings taking host 8085 to the node's port 80 and 8543 to 443, which is how you walk into the mall in Step 4. Those numbers were chosen deliberately instead of the usual 8080, because 8080 tends to be taken by something else on a working machine. Confirm with ss -ltn before you start; if either is busy, change the number in kind-p05.yaml and in the Step 4 commands.
- Internet access when you set the lab up: the setup downloads the Calico and Ingress controller manifests plus container images from quay.io, registry.k8s.io and docker.io. Grading itself needs no internet, only the live cluster and host port 8085.
- NODE IMAGE PINNED BY DIGEST, read out of the kind v0.32.0 binary itself on 2026-08-21: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5. The kind release notes say you must use the @sha256 digest to guarantee an image built for that release, not just the tag. Confirm yours with kind version and docker images --digests, never from memory. It is no longer the default image: the kind v0.33.0 binary this lab ran on, on 2026-10-09, ships kindest/node:v1.37.0, which is why kind-p05.yaml declares the pinned image.
- PINNED CNI: Calico v3.32.1, published 2026-06-26. It is pinned on purpose and is not the newest: as of 2026-10-09 the project had already published v3.32.2 and v3.33.0, according to its GitHub releases, and this lab ran end to end on v3.32.1 that same day. This piece is not decoration. The cluster is created with disableDefaultCNI set to true precisely because the CNI kind ships by default does not enforce NetworkPolicy, and without a CNI that enforces it the whole of Step 3 would be theatre. Watch one detail that costs dearly: the custom-resources.yaml that Calico publishes defaults to an IP pool of 192.168.0.0/16, which is the range of nearly every home network and collides with the LAN. That is why this lab does not use that file: it writes its own Installation resource with cidr 10.244.0.0/16, the same podSubnet declared to kind. Confirm the pool that actually came up with kubectl get ippools -o wide.
- THE SETUP MEASURES THE SUBSTRATE, it does not assume it. Before handing you the lab, the setup brings up a throwaway probe namespace, confirms one Pod talks to another with no policy in place, applies a total deny, and tests again. If traffic STILL passes, the setup prints the named error ERROR SUSTRATO-SIN-NETWORKPOLICY and exits non-zero, because on that cluster Step 3 would prove absolutely nothing. It is the only honest way to build a NetworkPolicy lab: an object can be accepted by the API and enforced by nobody.
- PINNED INGRESS CONTROLLER, and here the whole truth has to be said: ingress-nginx controller-v1.15.1, published 2026-03-19, is the LAST version that will ever exist. The kubernetes/ingress-nginx project was retired and its repository is archived read-only; there will be no more bug fixes and no more security patches, ever. Verified on 2026-10-09 against the GitHub API, which reports archived true for that repository and lists no later release. The manifest still downloads because an archived repository is not deleted, and the lab uses it deliberately, with an explicit pin, because Ingress is still on the CKAD curriculum and because knowing the mall lost the company that used to maintain its entrance is exactly the kind of thing a developer has to know before proposing it in production.
- APPLICATION IMAGES PINNED BY DIGEST, verified on 2026-08-21 with docker buildx imagetools inspect: nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de for the web servers, and busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0 for the client Pods, which is the image that carries nslookup and wget in the same binary and therefore covers both jobs in this lab. A tag is mutable, a digest is not.
- Having read Chapters 13, 14 and 15. This lab does not re-explain what a Service is, how a Service's DNS name is assembled, why an empty podSelector selects everything, or why creating an Ingress is not enough to make the entrance work; it makes you operate all three against a real cluster. The setup also hands you a deliberate fault, base64-encoded so you cannot read it at a glance. That is not real concealment, it is a courtesy so you diagnose instead of recognize; the answer is in Step 2's cmd field.

## Steps

The `0N-step.sh` is there so you never get stuck: read the step, try it on your own first, and run the script when you want to compare. It also writes the answer file the step asks for, reading the values from the live cluster.

### 1. Ch. 13: The shop's fixed name, even when the cooks change (10 pts)

Chapter 13 said it with the delivery: a customer does not ask for lunch to be sent to table 4 of the kitchen, because tomorrow the cook is at table 9 and lunch arrives cold at an empty spot. The customer orders in the name of the shop. Here's what's actually going on in Kubernetes: the shop is the Service, the cooks are the Pods, and the thing that translates the shop's name into the list of tables occupied today is the control plane, which keeps writing that list into an EndpointSlice every time a Pod appears or disappears.

In this step you build the central kitchen with three cooks, give it its ClusterIP Service, and confirm two things that almost everybody rolls into one.

The first is that the EndpointSlice filled in. Look at the ENDPOINTS column and compare it, address by address, with the IPs kubectl get pods -o wide shows. If the EndpointSlice is empty, it does not matter how perfect the Service looks: nobody is arriving.

The second is DNS, which is a different thing entirely. Bring up a client Pod and ask cluster DNS for the fully qualified name, with the four parts the chapter taught you: Service name, dot, namespace, dot, svc, dot, `cluster.local`. Stay and read the whole output rather than the last line: the first two lines carry 10.96.0.10 with the port attached, and that is NOT the answer, it is CoreDNS saying here I am. The answer comes further down, in the Name/Address block.

And no, resolving a name is not the same as reaching the shop. A name can resolve perfectly to a ClusterIP that leads nowhere because the Service has run out of endpoints. That is why this step's last command is not an nslookup but a wget against the name: nginx's HTML answering back is the only proof the delivery actually arrived.

DELIVERABLE: the cocina-central Deployment with 3 ready replicas, the domicilios Service, the el-mensajero Pod running, and the file `~/ckad-lab/p05/01-respuesta.txt`, exactly 3 lines:

```text
NOMBRE_COMPLETO=<the full name, ending in `svc.cluster.local`, that you asked DNS about>
CLUSTERIP_POR_DNS=<the address DNS returned for that name>
ENDPOINTS_LISTOS=<how many ready addresses the Service's EndpointSlice holds>
```

<details>
<summary>What you should see</summary>

The Deployment ends up with 3 of 3 replicas ready and kubectl get pods -o wide shows its three addresses. The domicilios Service is listed with TYPE ClusterIP, a CLUSTER-IP from the service range (something like 10.96.x.x) and PORT(S) 80/TCP. The EndpointSlice shows all THREE addresses in the ENDPOINTS column, exactly the ones the Pods show. The nslookup first prints the two server lines, Server and Address carrying 10.96.0.10 with the port attached, which are NOT the answer but who answered, and further down the Name/Address block with the full name and a single address, matching letter for letter what the spec.clusterIP jsonpath returns. The wget by name prints the first lines of nginx's welcome HTML: the name does not merely resolve, it also carries traffic.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 2. Ch. 13: The ice cream shop changed branch and the order still goes to the old one (10 pts)

The lab setup already left a second Service in the food court, called domicilios-heladeria, that has been sitting there since before you arrived and that has no endpoints at all. Not one. The EndpointSlice object exists, it has a name, it has an age, and inside it is empty. That is not a broken Service and Kubernetes has not jammed: somebody wrote a selector that no longer fits anybody. The ice cream shop changed branch and the order kept going out to the old one.

Your job is to diagnose it with Chapter 13's tools, not to guess it. Put the two truths side by side: the Service's selector on one side, the Deployment's pod template labels on the other, and identify which of the two keys does not line up. Notice there are two keys and only one of them is quarrelling.

And here this lab gives you a warning unlike the ones in other labs: IN THIS STEP EITHER REPAIR IS ACCEPTED. In real life both repairs are legitimate depending on whose contract the label is: if the branch name is owned by the application team, you fix the Service; if it is owned by the platform, you move the Deployment. Both routes pass. The only thing that does not pass is leaving the job half done.

What is required of you, written out in full in the check hint, is that both sides end up agreeing on the sede key, with the same value, and that the Service's EndpointSlice filled itself in, through the control plane, with the live addresses of those two Pods. Deleting the sede key from the selector so the problem goes away does not count: that is not reconciling, that is refusing to ask.

And since you are the one who knows what you did, the answer file asks you outright. The check does not take it on faith: it contrasts what you declared against the value left alive in the cluster, because the surviving branch name gives away which side moved.

The fault came base64-encoded inside the setup on purpose. It is not serious concealment, it is a courtesy so you diagnose instead of recognize; the full answer is in this step's cmd field, whenever you decide to reveal it.

DELIVERABLE: the domicilios-heladeria Service carrying its 2 endpoints, the Deployment with 2 ready replicas, and the file `~/ckad-lab/p05/02-respuesta.txt`, exactly 3 lines:

```text
SEDE_ACORDADA=<the value of the sede key the Service and the Deployment ended up agreeing on>
LADO_QUE_CAMBIE=<servicio, deployment or ambos, whichever side you moved>
ENDPOINTS_HELADERIA=<how many ready addresses the Service's EndpointSlice holds at the end>
```

<details>
<summary>What you should see</summary>

Before you touch anything, kubectl get svc shows the domicilios-heladeria Service with an ordinary CLUSTER-IP, as though it were perfect, and the EndpointSlice shows ENDPOINTS as <unset>, meaning empty, even though the EndpointSlice object does exist and has an age. The ice cream shop's Pods are Running, with their labels visible thanks to --show-labels. Printing the two jsonpaths reveals the clash: the Service selector says sede sur while the Deployment's pod template labels say sede norte, and the app key agrees on both sides. After the patch, that same EndpointSlice, same name and same age, fills up with the two Pod addresses: no new one was created, the existing one was updated.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 3. Ch. 15: First measure that the shop talks to anyone, and only then put the rule in (10 pts)

Chapter 15 ended on the most important warning in this part: a NetworkPolicy is just a piece of text stored in the API, and if the cluster's CNI cannot read it, you can apply the most elegant policy in the world, watch it listed by kubectl get, and see traffic keep flowing exactly as before. The lying watchman.

That is why this cluster was not created like the others. It was created with disableDefaultCNI set to true and Calico installed on top, deliberately, and the setup was not satisfied with merely installing it: it brought up a throwaway probe namespace, measured that one Pod talked to another, applied a total deny, measured again, and only handed you the lab once it confirmed the second attempt failed. Had that measurement not passed, the setup would have died with a named error instead of leaving you performing a decorative step.

And that is why this step's order cannot be reversed. MEASURE first. Before applying anything, run both wgets and see with your own eyes that both exit 0: the arcade has no locks, anyone walks into any shop. That baseline is not paperwork, it is the only way to know afterwards that what changed was the policy and not something else.

Then put the rule in, and put it in as two pieces, which is how it is really done. The first is the default deny: empty podSelector, meaning ALL Pods in the namespace, policyTypes carrying Ingress, and no rule inside. Remember what the chapter said: an empty podSelector does not select nobody, it selects everybody. The second is the one that opens a single door: it applies to Pods with rol=local and lets in only those carrying the label acceso=permitido, and only over port 80.

Now repeat the measurement. The badged courier walks in as if nothing happened. The street vendor stands there for a full five seconds and gives up. Notice that detail because the exam asks it a thousand ways: nobody tells it no, nobody answers it at all. A packet blocked by a network policy does not bounce, it is dropped, and that is why what you see is a timeout and not a connection refused.

One last warning, and this one is serious: if it occurs to you to hand the street vendor a badge so the symptom disappears, traffic will flow and the step will fail. It is stated outright in the check hint.

DELIVERABLE: the three Pods running in la-galeria with their labels, both NetworkPolicies applied, and the file `~/ckad-lab/p05/03-respuesta.txt`, exactly 2 lines:

```text
SALIDA_CON_CARNET=<the exit code of the badged courier's wget AFTER applying the policies>
SALIDA_SIN_CARNET=<the exit code of the street vendor's wget AFTER applying the policies>
```

<details>
<summary>What you should see</summary>

In the baseline both wgets return exit code 0: the arcade is wide open and any Pod talks to any other, exactly as the Kubernetes networking model says. After applying both policies, the badged courier's wget still returns 0, and the street vendor's goes silent for a full five seconds and returns 1, which is what a timeout looks like rather than a refusal: nobody tells it no, nobody answers it at all. kubectl get networkpolicies lists both policies, and the default-deny one shows POD-SELECTOR as <none>, which is how kubectl displays the empty selector that selects everything.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 4. Ch. 14: The directory at the entrance sends everyone to the right store (10 pts)

Chapter 14 was blunt about one thing: the directory can be perfectly bolted to the wall of the entrance, but if nobody hired the company that runs that entrance, the sign takes nobody anywhere. Creating an Ingress has no effect without an Ingress controller to serve it.

On this cluster the company is already hired: the setup installed ingress-nginx, and here the whole truth has to be said, the same truth the prerequisites tell. That project was retired and its repository is archived read-only. The version you have installed, controller-v1.15.1, published 2026-03-19, is the last one that will ever exist: no more patches, not even security ones. The entrance works, but the company that used to maintain it shut down. We tell you because a developer proposing a controller without knowing that is making a decision with half the information missing.

Your job is the directory. Build two stores, each with its Deployment and its Service, each serving different text so there is no doubt afterwards about which one answered. Then write ONE Ingress with two paths, /ropa and /helados, each pointing at the Service it belongs to.

And do not skip ingressClassName. Chapter 14 explained what it is for: a single cluster can have several controllers installed, and that field is what says, unambiguously, which of them serves this list of rules. Before writing it, look at what is available with kubectl get ingressclass and confirm with jsonpath which controller backs it, instead of typing nginx from memory.

To get in from outside, use curl against host port 8085, which the setup mapped to the node's port 80, and send the Host header the rule expects. That is exactly what a browser does when somebody types the domain, only without needing DNS. And do not skip the third curl, with a host that exists in no rule: the code it returns is one of the three lines you have to deliver, and it cannot be guessed without running it.

A warning about timing: the controller does not reload its rules the instant you apply. If you curl straight away it answers 404 and it looks as though the Ingress were useless. That is why this step's command retries in a bounded loop before calling the result good, and the check does the same.

DELIVERABLE: both Deployments with their Services in el-centro-comercial, the directorio-de-la-entrada Ingress with both paths, and the file `~/ckad-lab/p05/04-respuesta.txt`, exactly 3 lines:

```text
CLASE_DEL_DIRECTORIO=<the spec.ingressClassName value you gave the Ingress>
HOST_DEL_DIRECTORIO=<the host the Ingress rule declared>
HTTP_HOST_DESCONOCIDO=<the HTTP code the curl with a host that is in no rule returned>
```

<details>
<summary>What you should see</summary>

kubectl get ingressclass lists the nginx class, and the jsonpath prints k8s.io/ingress-nginx, the name of the controller that serves it. The Ingress is listed with CLASS nginx, HOSTS centrocomercial.local and PORTS 80. The describe shows both paths with their backends and, under each one, the addresses of the Pods behind them, not just the Service name. The first curl prints LOCAL DE ROPA and the second prints LOCAL DE HELADOS, each coming out of the correct Service. The third curl, with a host that appears in no rule, returns HTTP 404: the directory exists, but that mall is not on the list.

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

- **Symptom (step 1):** nslookup answers NXDOMAIN or server can't find
  **What to do:** It is almost always the name, not DNS. Confirm you typed all four parts: `service.namespace.svc.cluster.local`. A Pod living in another namespace cannot ask for the short name alone, it has to give at least service.namespace. If the full name does not resolve either, check that the CoreDNS Pods are Running with $K -n kube-system get pods -l k8s-app=kube-dns.

- **Symptom (step 1):** nslookup returns an address but wget hangs
  **What to do:** That is exactly the case this step wants to teach you: the name resolves and the destination does not answer. Look at the Service's EndpointSlice; if the ENDPOINTS column shows <unset>, the Service has nobody to send traffic to and the name resolves to a hollow ClusterIP. Check that the Service selector matches the Deployment's pod template labels and that the Pods are Running.

- **Symptom (step 1):** wget: unrecognized option: -T
  **What to do:** That error means the wget that ran is not busybox's. Confirm the client Pod was created with this step's digest-pinned busybox image and not with something else you had lying around. If you prefer another image, use its timeout equivalent, but do leave a bounded timeout: without one the wget hangs and you never see the exit code.

- **Symptom (step 2):** kubectl get endpointslices returns nothing for domicilios-heladeria
  **What to do:** Confirm you are querying the la-plazoleta namespace and that the filter label is exactly kubernetes.io/service-name=domicilios-heladeria. That is the label name the control plane puts on every EndpointSlice to bind it to its Service; written any other way the filter finds nothing and you conclude it does not exist when it does.

- **Symptom (step 2):** The patch fails with an error saying the path does not exist
  **What to do:** A json-type patch with the replace operation requires the path to already exist. If you already deleted the sede key, the right operation is add instead of replace, or more simply edit the object with kubectl edit and leave it as it should be. The check grades the end state, not the command you used to get there.

- **Symptom (step 2):** I moved the Deployment and now the check fails even with 2 ready replicas
  **What to do:** Changing a pod template label triggers a new rollout: for a few seconds Pods from the old and the new revision coexist, and the EndpointSlice address set does not agree with the new branch's Pods. Wait for it to finish with $K -n la-plazoleta rollout status deploy/heladeria-la-nieve, give it a few more seconds for the EndpointSlice to catch up, and grade again. Careful: the app key cannot be moved, because it also lives in the Deployment's spec.selector.matchLabels and that field is immutable.

- **Symptom (step 3):** After applying the policies, the street vendor still gets in with exit code 0
  **What to do:** That is exactly the lying watchman's symptom, and the first thing to rule out is the CNI. Confirm Calico came up with $K get tigerastatus and that the calico-system Pods are Running; if the cluster was created without disableDefaultCNI, or Calico never finished installing, the policies sit in the API and nobody enforces them. The second thing to check is that both policies are in the la-galeria namespace and not in default: a NetworkPolicy only acts inside its own namespace. And third, give it a few seconds: the CNI does not program the rules the instant you apply.

- **Symptom (step 3):** Now the badged courier cannot get in either
  **What to do:** Check the policy that opens the door, in this order. That its podSelector points at rol=local, which is the juice shop's label and not the client's. That the ingress rule carries a from with a podSelector saying acceso=permitido. And that the declared port is 80 TCP, which is where nginx listens: a rule opening the wrong port looks perfect in the YAML and blocks just as if it did not exist.

- **Symptom (step 3):** The street vendor's wget hangs and never comes back
  **What to do:** You left out the timeout. A packet blocked by a NetworkPolicy does not bounce, it is dropped, so without -T the wget waits for the system default and you sit staring at the terminal. Use -T 5 as in this step's command; that bounded number is what turns the block into an exit code you can measure.

- **Symptom (step 4):** curl returns 404 on both paths
  **What to do:** Check four things in this order. That you gave the controller time to reload: wait a few seconds and retry, because the apply is not instantaneous. That you are sending the Host header and that it matches the rule's host letter for letter: without that header the controller finds no rule to apply. That you are requesting /ropa/ with the trailing slash, because the content lives in a subdirectory and nginx answers 301 towards the slash if you leave it off. And that the Ingress describe shows Pod addresses under each backend: if it comes up empty, the problem is not the entrance but that the Service behind it has no endpoints.

- **Symptom (step 4):** curl cannot connect to localhost:8085
  **What to do:** That port only exists because the cluster was created with extraPortMappings. Confirm with docker port ckad-p05-control-plane that host 8085 is mapped to the node's 80; if it does not show up, the cluster was created without the kind-p05.yaml file and has to be rebuilt, because extraPortMappings cannot be added to an existing cluster.

- **Symptom (step 4):** kubectl apply of the Ingress fails with an admission webhook error
  **What to do:** ingress-nginx installs a ValidatingWebhookConfiguration that reviews every Ingress before accepting it. If the controller has not finished starting, that webhook does not answer and the apply fails. Wait for the controller Pod to be ready with $K wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s and apply again.

## Going further

- Create a headless Service in la-plazoleta, with clusterIP set to None and the same selector as cocina-central, and re-run the nslookup from el-mensajero. Count the records it returns. Then scale the Deployment to 5 replicas and repeat. Without touching DNS or the Service, the number of answers changes on its own, and that shows you where the list CoreDNS answers with really comes from.
- Delete the sede key from the domicilios-heladeria selector instead of reconciling its value, and observe that the Service fills with endpoints just the same. Then explain in your own words why a selector with fewer keys selects MORE Pods, not fewer, and what would happen if another Deployment in the same namespace also carried the label app=heladeria-la-nieve.
- Add a third, egress policy in la-galeria stopping the badged courier from reaching anywhere except the cluster DNS, and confirm that wget by name now fails while wget by IP still passes. It is a production mistake with NetworkPolicy: closing egress and forgetting to open port 53.
- Add a second host rule to the same Ingress, with a different host and a single path, and confirm with curl that the same controller serves both domains without you installing anything new. That is the name-based virtual hosting the official documentation talks about, in a single object.

## References

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
