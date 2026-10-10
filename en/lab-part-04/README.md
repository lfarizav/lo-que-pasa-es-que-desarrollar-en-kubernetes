# Part IV - Lab: a stall that did not fit in the market and had to be measured, a menu you read and a safe you never copy, an employee in uniform who still gets the work done, and an ID card that opens one door and no other

- Time: 55 min
- Points: 40

## Objective

This is an Exam-Style lab: each step tells you only the objective and the deliverable, and the command sequence that solves it lives in that step's cmd field for you to reveal after trying it with your own hands. Step 1 hands you a Pod manifest the API server rejects to your face, because the market's management put a ResourceQuota on that namespace, and asks you to make it start by properly sizing what the stall asks for and what it is allowed to use; grading requires the Pod to end up running and the quota to remain intact, so deleting or loosening the quota is the fastest way to lose the step. Step 2 sets up Chapter 10's business: you create the menu of the day as a ConfigMap and consume that menu plus the safe's key that already exists, both at once as environment variables and as mounted files, and grading enters the live container to read the mounted values and on top of that checks that the key arrives by reference and not typed by hand into the manifest. Step 3 puts Chapter 12's mandatory uniform on you: a hardened Pod that does not run as root, whose root filesystem is read only and which drops every capability, and which still gets its work done; grading reads the declared fields and then asks the live process who it is and what it can do. Step 4 closes with the ID card: a dedicated ServiceAccount, with a Role and a RoleBinding granting exactly the verbs the application needs and not one more, checked with kubectl auth can-i from both sides and genuinely exercised from inside the Pod against the API server; giving the card cluster-admin fails the step, which is precisely what had to happen.

## Prerequisites

- A Linux machine with kind, kubectl and docker on PATH, internet access, and at least 4 GB of free RAM. This lab creates its own kind cluster named ckad-p04, with a single node, and deletes it at the end. Everything it does goes through a private kubeconfig at ~/ckad-lab/p04/kubeconfig, passed with --kubeconfig on every single command: your usual kubeconfig is never touched, your current context never changes, and no other cluster of yours is affected. Do not run this lab against a production cluster.
- Versions pinned and verified on 2026-10-09 on the machine where this lab was executed: kind v0.33.0, kubectl v1.37.0, node image kindest/node:v1.36.1 pinned by digest sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5, and the workload image busybox:1.37.0 pinned by digest sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0. Confirm your kind with kind version and your kubectl with kubectl version --client before you start, rather than taking this paragraph's word for it.
- The setup script does not just build the cluster: it runs three tests on it before letting you start, because all four steps assume three behaviors a cluster can accept over the API and never actually enforce. It checks that the ResourceQuota really does reject a Pod with no sizing, that the RBAC authorization mode really does say no, and that runAsNonRoot really does stop an image that runs as root from starting. If any of them fails, the setup prints a named error and stops, because a lab that grades a control nobody enforces is decoration.
- Every step works inside the plaza namespace and that namespace has a ResourceQuota placed by the setup. That means every Pod you create in this lab, not only Step 1's, has to declare CPU and memory requests and limits, or the API server rejects it. It is not the exercise being fussy: it is the real effect of having a compute quota on a namespace, and all four checks re-read the quota to confirm it is still the way it was.
- Having read Chapters 9, 10, 11 and 12. This lab does not re-explain what a request is, what the difference between a ConfigMap and a Secret is, what a CustomResourceDefinition is or what a RoleBinding does; it makes you operate all four against a real cluster and grades them against its real state.

## Steps

The `0N-step.sh` is there so you never get stuck: read the step, try it on your own first, and run the script when you want to compare. It also writes the answer file the step asks for, reading the values from the live cluster.

### 1. Ch. 9: The stall did not fit in the market, and the market is not getting bigger (10 pts)

Chapter 9 explained that in the market square every stall takes up a piece, and management keeps the running total. Here you get to live it from the uncomfortable side: somebody left you a ready-to-apply manifest, you apply it in good faith, and the API server hands it straight back to you.

What happens is that this rejection is neither a syntax mistake of yours nor a cluster problem. It is the plaza namespace's ResourceQuota doing exactly what it was asked to do. And the message it returns is one of the most generous Kubernetes gives, because it hands you all three figures: requested (what you asked for), used (what was already taken) and limited (the namespace's ceiling). With those three, sizing the stall is shopkeeper arithmetic, not guesswork.

And watch out for one thing that is very expensive on exam day: when a namespace has a quota on compute resources, every Pod entering it must declare CPU and memory requests and limits. It is not optional, it is not a good practice, it is admission. If you forget a single field, the error no longer says exceeded quota but must specify limits.cpu, and plenty of people lose ten minutes hunting for where they oversized when what was missing was a field.

And here comes the one that hurts most: the easy way out is not to make the market bigger. Deleting the quota, raising its number or putting a wider quota beside it gets the Pod up in three seconds and gets you a failed step, because the stall got in but the market no longer has management. On a real cluster that is the difference between one team running out of memory and one whole node going down because of you. Evicting the neighbor does not count either: the juice stall that was already there is not yours, and taking it out to make room is the same shortcut with more steps.

DELIVERABLE: the `puesto-de-frutas` Pod running in the plaza namespace, `puesto-de-jugos` untouched, the `cupo-de-la-plaza` ResourceQuota exactly as the setup left it, and the file `~/ckad-lab/p04/01-respuesta.txt`, exactly 2 lines:

```text
CUPO_DE_MEMORIA_PEDIDA=<the requests.memory ceiling the ResourceQuota declares>
MEMORIA_PEDIDA_POR_EL_PUESTO=<the requests.memory your puesto-de-frutas container declares, written exactly as the cluster returns it>
```

<details>
<summary>What you should see</summary>

The first apply crashes and the error says exactly what happened: pods "puesto-de-frutas" is forbidden: exceeded quota: cupo-de-la-plaza, requested: limits.cpu=2,limits.memory=2Gi,requests.cpu=1,requests.memory=1Gi, used: limits.cpu=800m,limits.memory=800Mi,requests.cpu=400m,requests.memory=400Mi, limited: limits.cpu=2,limits.memory=2Gi,requests.cpu=1,requests.memory=1Gi. Notice the message carries the three figures that matter: what you asked for, what was already taken by the juice stall, and the namespace's ceiling. With the manifest properly sized, the second apply creates the Pod, the wait returns pod/puesto-de-frutas condition met, and the listing shows both stalls Running. The last three lines print cupo_pedido_memoria=1Gi and, on the machine where this lab was executed, en_uso_memoria=528Mi and memoria_pedida_por_el_puesto=128Mi. The 528Mi is the juice stall's 400Mi plus the 128Mi you just asked for; that middle figure will keep climbing as you create the Pods from Steps 2, 3 and 4, so it is not the one you record. The first and the third are stable: the ceiling belongs to the quota and the third is the size you chose.

</details>

```bash
./01-step.sh
./01-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 2. Ch. 10: The menu is read out loud, the safe's key gets copied onto no piece of paper (10 pts)

Chapter 10 showed you the two boards every business has: the menu of the day, hung where everyone can see it and changed whenever the owner likes, and the safe behind the counter, which also gets opened, but not in front of the customers. ConfigMap and Secret are exactly that, and in Kubernetes they are consumed identically: as environment variables or as mounted files.

What happens is that people learn only one of the two and then get lost on exam day. As an environment variable, the value is handed to the process when the container starts, and it stays frozen there until the Pod is recreated. As a mounted file, each key becomes a file named after the key, and the kubelet refreshes it as the object changes. That is why this step asks for both: so you see with your own eyes that the same value arrives by two different routes and that neither of them is "the right one".

About the Secret the whole truth has to be told, because half the world tells it halfway: base64 is not encryption. It is encoding, and one command undoes it. A Secret does not protect the value from whoever can read the object; what it does is take it out of the manifest, out of the code repository, and put it behind an RBAC permission that can be denied. That denial is precisely what you are going to build in Step 4.

And here is the mistake this step grades in earnest: typing the key by hand into the manifest. Writing env with name CLAVE_DE_LA_CAJA and value holding the key produces exactly the same printenv, looks just as good in the demo, and is exactly what the Secret existed to prevent; that manifest goes into the repository with the key inside it. The same goes for mounting an emptyDir and writing the file at startup. Grading looks at where the value came from, not at how it looks.

DELIVERABLE: the `menu-del-dia` ConfigMap with the keys `plato-del-dia` holding ajiaco-santafereno and `postre-del-dia` holding brevas-con-arequipe, and the `cocinero` Pod running in the plaza namespace consuming the ConfigMap and the `caja-fuerte` Secret by both routes: the `PLATO_DEL_DIA` variable from the ConfigMap, the `CLAVE_DE_LA_CAJA` variable from the Secret, the ConfigMap mounted at `/etc/menu` and the Secret mounted at /etc/caja. Plus the file `~/ckad-lab/p04/02-respuesta.txt`, exactly 3 lines:

```text
PLATO_MONTADO=<the contents of the dish's file, read inside the container>
CLAVE_LARGO=<how many characters the key has, counted inside the container>
ORIGEN_DE_LA_CLAVE=<the exact name of the valueFrom field you used to bring the key in from the Secret>
```

<details>
<summary>What you should see</summary>

The Secret query prints tipo=Opaque and a list of keys whose value already comes base64 encoded, which is encoding and not encryption: anyone who can read the Secret can read the key, and that is why permission to read Secrets is handed out with an eyedropper in Step 4. The Pod starts without drama and the ls shows the clave file inside /etc/caja and the two files plato-del-dia and postre-del-dia inside `/etc/menu`, each key's name turned into a file name. The cat and the printenv both print ajiaco-santafereno, which is the proof that the same value arrived by both routes, mounted and as an environment variable; in the terminal you will see them stuck together on one line, ajiaco-santaferenoajiaco-santafereno, because the mounted file carries no trailing newline and the value ends exactly where the next one begins. The wc -c on the secret's mounted file returns 30 on the machine where this lab was executed, with no trailing newline: a mounted Secret adds nothing to the value.

</details>

```bash
./02-step.sh
./02-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 3. Ch. 12: The uniform is mandatory, and the work still gets done wearing it (10 pts)

Chapter 12 talked to you about the mandatory uniform: in the business nobody walks into the kitchen in their own clothes, and it is not about fashion. The securityContext is the Pod's uniform, and this step asks you to put the full set on a container that still has to keep working, which is the hard part.

What happens is that the three pieces of the uniform attack three different things and people mix them up. runAsNonRoot is a promise the kubelet verifies before starting: if the image was going to run as root, the container does not start and you see CreateContainerConfigError with the literal message image will run as root. runAsUser is the employee's specific number, and without it an image that declares no user of its own has no way to keep the promise. readOnlyRootFilesystem mounts the container's filesystem read only, meaning whoever gets in there can leave nothing written behind. And capabilities.drop with ALL strips the process of every one of root's partial superpowers, the ones you forget exist until somebody uses them.

Here is what makes this step useful and not merely strict: the container has to keep writing its heartbeat. A uniform that stops the work getting done is one nobody wears, and in production the team takes it off after the third incident. The answer is the usual Kubernetes one: if the process needs to write, give it a writable volume at the exact path where it writes, and leave the root filesystem read only. That is hardening properly, and it is different from hardening until it breaks.

And here comes a confusion worth avoiding: leaving drop ALL in place and adding a capability back with capabilities.add "just in case". The manifest looks hardened, the code review passes, and the process's bounding set is no longer empty. This grading reads CapBnd as well as CapEff for precisely that reason, so that "just in case" is visible.

DELIVERABLE: the `uniformado` Pod running and Ready in the plaza namespace, not running as root, with a read only root filesystem, with no capabilities, not allowing privilege escalation, and still writing a recent heartbeat to `/var/latidos/pulso.txt`. Plus the file `~/ckad-lab/p04/03-respuesta.txt`, exactly 3 lines:

```text
UID_DEL_PROCESO=<the uid the process reports from inside the container>
CAPEFF=<the CapEff value the process reports in /proc/self/status>
RAIZ_ESCRIBIBLE=<answer si or no, lowercase, according to what happens when you try to write to /tmp from inside>
```

<details>
<summary>What you should see</summary>

The Pod goes Ready with no retries. The id prints uid=1000 gid=3000 groups=3000, which is not what the busybox image ships by default (root), but what you imposed on it. The three capability lines print CapPrm, CapEff and CapBnd all at 0000000000000000: the process is not merely not using privileges, it has none left even in the bounding set, so there is nothing to regain. The attempt to write in /tmp returns sh: can't create /tmp/prueba.txt: Read-only file system with exit code 1, because /tmp is part of the root filesystem and the root filesystem is read only; that detail matters, because an unprivileged uid could not write to / anyway, but it could write to /tmp if the root filesystem were writable. And with the whole uniform on, the last command still prints two nearly identical numbers, the heartbeat the container wrote inside the emptyDir volume and the current time: readOnlyRootFilesystem never meant the process cannot write anywhere.

</details>

```bash
./03-step.sh
./03-check.sh
```

The grader prints `ok` and exits 0 when the step is right, and exits 1 when it is not. It does not take your word for it: it queries the live cluster again.

### 4. Ch. 11 and 12: An ID card that opens the menu's door and the orders' door, and no other (10 pts)

Chapter 11 told you that sometimes the neighborhood needs a service that did not exist, and that in Kubernetes you solve that by inventing the form: a CustomResourceDefinition adds a new type to the API server, and from that moment kubectl treats it like any other. On this cluster the setup already registered the Pedido type, in the plaza.example.com group, and left an order from table 4. Chapter 12 told you the other half: that inside the cluster applications have an identity too, and that identity is the ServiceAccount.

What happens is that it is easy to discover ServiceAccounts only on the day an application starts failing with 403 and they search the internet for how to fix it. The first answer they find is to give it cluster-admin, it works immediately, and that is how a compromised container ends up able to read every Secret in the cluster. This step is built so that way out does not work.

The model is three pieces and you have to keep them separate in your head. The ServiceAccount is the ID card: it says who, it does not say what. The Role is the list of what may be done, and because it is a namespaced object, what it says applies only inside that namespace. The RoleBinding is the act of handing that permission to that card, and without it the Role is a nice piece of paper that opens nothing. And when the application needs a resource you invented yourself with a CRD, that resource is named in the Role like any other, with its own apiGroup.

The tool that will save your exam is kubectl auth can-i with --as. It lets you ask the API server, without deploying anything, whether a specific identity can perform a specific action. Always use it from both sides: ask about what must be allowed and ask about what must not. A permission tested only from the positive side is not tested, it is assumed.

And then comes the usual temptation: cluster-admin is not a quick fix, it is giving up on the whole model. And if you are tempted to think this lab is exaggerating, look at the Secret's 403 from inside the Pod and think about how many containers at your job could make that same call and get a 200.

DELIVERABLE: the `carnet-del-mesero` ServiceAccount in the plaza namespace, a Role and a RoleBinding in that namespace granting exactly get and list on configmaps and on pedidos.plaza.example.com and nothing more, and the `mesero` Pod running with that card on. Plus the file `~/ckad-lab/p04/04-respuesta.txt`, exactly 5 lines:

```text
CUENTA_DEL_MESERO=<the name of the ServiceAccount the mesero Pod declares>
PUEDE_LEER_EL_MENU=<what kubectl auth can-i get configmaps answers for that card>
PUEDE_BORRAR_EL_MENU=<what kubectl auth can-i delete configmaps answers for that card>
PUEDE_LEER_LOS_PEDIDOS=<what kubectl auth can-i get pedidos.plaza.example.com answers for that card>
CODIGO_EN_LA_CAJA=<the HTTP code the API server returns when the mesero Pod asks for the caja-fuerte Secret with its token>
```

<details>
<summary>What you should see</summary>

The CRD query prints grupo=plaza.example.com, plural=pedidos and alcance=Namespaced, and the get pedidos lists pedido-de-la-mesa-4: that resource did not exist in the neighborhood and is now queried with kubectl just like a Pod, which is the whole point of Chapter 11. The seven auth can-i questions answer, in order, yes, yes, no, no, yes, no and no. Notice the pattern: the card reads the menu and reads the orders, and deletes neither of them, does not open the safe, and cannot do everything in every namespace. From inside the Pod, the card's namespace prints plaza, and the three calls to the API server with the projected token return HTTP/1.1 200 for the ConfigMap, HTTP/1.1 200 for the orders list, and HTTP/1.1 403 for the Secret. That 403 is the important part: it is not that the waiter cannot find the safe, it is that the API server knows who is asking and tells them no.

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

- **Symptom (step 1):** The error does not say exceeded quota, it says must specify limits.cpu, limits.memory, requests.cpu, requests.memory
  **What to do:** That is a different error with a different cause: the Pod is missing one of the four fields, and with a compute quota in place that alone is grounds for rejection, whatever the size. It happens every time you create a Pod with kubectl run or copy an example manifest with no resources block. Add CPU and memory requests and limits to every container in the Pod and re-apply. Check which resources the quota demands with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard}': every compute resource listed there is a mandatory field on every container.

- **Symptom (step 1):** The Pod was created but sits in Pending and never starts
  **What to do:** If the Pod exists, the quota already admitted it: the problem is now the scheduler's, not the market management's. A CPU or memory request can fit comfortably in the namespace's quota and still fit on no real node, because the quota measures the whole namespace and the scheduler measures one machine. Read the verbatim reason in the events with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza describe pod puesto-de-frutas and compare what your Pod asks for against what the node has free, with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig describe node. This kind cluster has a single node, so a multi-GB request will not fit even if the quota allows it.

- **Symptom (step 2):** The Pod sits in CreateContainerConfigError and describe talks about a key it cannot find
  **What to do:** A configMapKeyRef or a secretKeyRef pointing at a key that does not exist stops the container from being configured, and the Pod does not even start. That is different from a badly wired volume, which does start and then fails on read. List the real keys with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get configmap menu-del-dia -o jsonpath='{.data}' and kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get secret caja-fuerte -o jsonpath='{.data}', and compare them letter by letter against your manifest. One possible mistake is writing plato_del_dia with underscores when the key is called plato-del-dia with hyphens.

- **Symptom (step 2):** You changed the ConfigMap and the environment variable still shows the old value
  **What to do:** It is not a bug: an environment variable is computed once, when the container starts, and never looked at again. The mounted file does update, with a delay of up to roughly a minute because the kubelet refreshes it on its own cycle. Check it yourself: change the ConfigMap with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza edit configmap menu-del-dia, wait, and compare kubectl ... exec cocinero -- cat `/etc/menu/plato-del-dia` against kubectl ... exec cocinero -- printenv PLATO_DEL_DIA. For the variable to change, the Pod has to be recreated. Careful: this check requires the ConfigMap to hold the values from the brief, so if you experiment, put it back the way it was before grading.

- **Symptom (step 3):** The Pod sits in CreateContainerConfigError with the message container has runAsNonRoot and image will run as root
  **What to do:** The kubelet is keeping the promise you made it: you told it runAsNonRoot true and the image declares no user, so it was going to run as root and the kubelet refuses to start it. The busybox image ships no USER instruction, which is why you have to give it the number by hand: add runAsUser with a non-zero uid (1000 for instance) to the Pod's or the container's securityContext. See the full message with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza describe pod uniformado. And note this error comes from the kubelet, not from the API server: the Pod was admitted, it was scheduled, and it failed while configuring the container.

- **Symptom (step 3):** The container starts and dies immediately, in a loop, and the logs talk about Read-only file system
  **What to do:** Your process is trying to write to a path that is now read only, and that is the normal reaction of almost every piece of software when its root filesystem is hardened without giving it somewhere to write. The right fix is not to turn readOnlyRootFilesystem off: it is to find out which path it writes to and mount a writable volume there, usually an emptyDir. Read the exact path in the logs with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza logs uniformado --previous, and add a volumeMount at that path. If the process writes to /tmp, mount the emptyDir at /tmp; if it writes to its own data directory, there. That is exactly the conversation you are going to have with the application team at work.

- **Symptom (step 4):** auth can-i answers no for get configmaps even though the Role and the RoleBinding exist
  **What to do:** Almost always the RoleBinding points at the wrong subject. A ServiceAccount subject needs its namespace as well as its name, and if you leave the namespace out the binding ends up pointing at an account that does not exist, without raising any error. Look at the real subject with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig -n plaza get rolebinding el-mesero-lee-el-menu -o yaml and confirm it says kind ServiceAccount, name carnet-del-mesero and namespace plaza. The other frequent cause is a roleRef pointing at a ClusterRole when you created a Role, or the other way round: roleRef is immutable, so if it is wrong you have to delete the RoleBinding and create it again.

- **Symptom (step 4):** auth can-i answers yes for get pedidos but the Pod gets a 403 when asking for the list
  **What to do:** get and list are different verbs in RBAC, and asking for a whole collection is list, not get. This mistake shows up with custom resources because you test with kubectl get pedidos, which internally does a list, and then the application code does the same. Confirm both separately with kubectl --kubeconfig ~/ckad-lab/p04/kubeconfig auth can-i list pedidos.plaza.example.com -n plaza --as=system:serviceaccount:plaza:carnet-del-mesero and add list to the Role if it is missing. And check that rule's apiGroups: for a CRD resource it has to be the CRD's group, plaza.example.com, not the empty string used for core resources.

## Going further

- Add a LimitRange to the plaza namespace with a default and a defaultRequest for CPU and memory, then try to create a Pod with no resources block. You will see it is admitted now, because the LimitRange fills the fields in before the quota inspects it, and that the resulting Pod has requests and limits you never wrote. Compare that with what happened to you in Step 1 and draw your own conclusion about which of the two objects is worth putting into a genuinely shared namespace first.
- Change the value of one key in the menu-del-dia ConfigMap with kubectl edit and do not touch the cocinero Pod. Wait a minute and compare what the cat of the mounted file returns against what the printenv of the variable returns. Time how long the file takes to change, which depends on the kubelet's sync cycle, and note the difference: it is exactly why an application that re-reads its configuration from a mounted file can be reconfigured without restarting and one that reads it from the environment cannot. Put the ConfigMap back to the values in the brief before grading Step 2 again.
- Apply the Pod Security Admission labels to the plaza namespace in warn mode, with pod-security.kubernetes.io/warn=restricted, then recreate the Pods from Steps 2 and 4 exactly as you have them. Read carefully the warnings the API server prints about each missing field, and compare them with the securityContext you put on Step 3's Pod. That exercise tells you, without breaking anything, how far your everyday manifests are from passing the restricted profile.
- Write an additional Role letting carnet-del-mesero create and update pedidos.plaza.example.com, but only the object named pedido-de-la-mesa-4, using the rule's resourceNames field. Then check with auth can-i, naming the resource, what the API server answers, and observe that resourceNames does not apply to collection verbs such as list. That asymmetry is one of the things that surprises people most the first time they design fine-grained permissions.

## References

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
