#!/usr/bin/env bash
# lab-part-01 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p01
KC="$HOME/ckad-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-ckad-p01"
BUSYBOX=busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K explain pod.spec.initContainers
$K explain pod.spec.volumes.emptyDir

cat > el-almuerzo.yaml <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: el-almuerzo-del-dia
  namespace: la-nevera
spec:
  volumes:
  - name: la-nevera
    emptyDir: {}
  initContainers:
  - name: el-ayudante
    image: $BUSYBOX
    command: ["sh","-c","echo el-ayudante-dejo-listo-el-mise-en-place > /nevera/index.html"]
    volumeMounts:
    - name: la-nevera
      mountPath: /nevera
  containers:
  - name: el-cocinero
    image: $BUSYBOX
    command: ["httpd","-f","-p","8080","-h","/nevera"]
    volumeMounts:
    - name: la-nevera
      mountPath: /nevera
YAML

$K apply -f el-almuerzo.yaml
$K -n la-nevera wait --for=condition=Ready pod/el-almuerzo-del-dia --timeout=300s

$K -n la-nevera get pod el-almuerzo-del-dia \
  -o jsonpath='{.status.initContainerStatuses[0].name}{" -> "}{.status.initContainerStatuses[0].state.terminated.reason}{"\n"}'
$K -n la-nevera get pod el-almuerzo-del-dia -o json \
  | jq -r '.spec.volumes[] | "volumen \(.name) tipo \((keys_unsorted - ["name"])[0])"'
$K -n la-nevera exec el-almuerzo-del-dia -c el-cocinero -- cat /nevera/index.html
$K -n la-nevera exec el-almuerzo-del-dia -c el-cocinero -- wget -qO- 127.0.0.1:8080/index.html

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p01"
cat > "$D/04-respuesta.txt" <<EOF
ESTADO_DEL_AYUDANTE=$($K -n la-nevera get pod el-almuerzo-del-dia -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}')
TIPO_DE_VOLUMEN=$($K -n la-nevera get pod el-almuerzo-del-dia -o json | jq -r '.spec.volumes[0] | (keys_unsorted - ["name"])[0]')
LO_QUE_SIRVE_LA_COCINA=$($K -n la-nevera exec el-almuerzo-del-dia -c el-cocinero -- wget -qO- 127.0.0.1:8080/index.html | tr -d '\r' | head -1)
EOF
cat "$D/04-respuesta.txt"
