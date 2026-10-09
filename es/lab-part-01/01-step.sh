#!/usr/bin/env bash
# lab-part-01 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p01
KC="$HOME/ckad-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-ckad-p01"

cat receta/Dockerfile
cat receta/carta.html

docker build -t la-receta:1.0 ./receta
docker image ls la-receta

kind load docker-image la-receta:1.0 --name ckad-p01

NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}')
docker exec "$NODO" crictl images | grep la-receta

$K -n la-cocina create deployment el-restaurante --image=la-receta:1.0 --replicas=2
$K -n la-cocina rollout status deployment/el-restaurante --timeout=180s

$K -n la-cocina get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{" politica="}{.spec.containers[0].imagePullPolicy}{" imageID="}{.status.containerStatuses[0].imageID}{"\n"}{end}'

POD=$($K -n la-cocina get pods -o jsonpath='{.items[0].metadata.name}')
$K -n la-cocina exec "$POD" -- wget -qO- 127.0.0.1:8080/index.html

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p01"
NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}')
cat > "$D/01-respuesta.txt" <<EOF
REPLICAS_LISTAS=$($K -n la-cocina get deploy el-restaurante -o jsonpath='{.status.readyReplicas}')
IMAGEN_DEL_DESPLIEGUE=$($K -n la-cocina get deploy el-restaurante -o jsonpath='{.spec.template.spec.containers[0].image}')
IMAGEN_EN_EL_NODO=$(docker exec "$NODO" crictl images -o json | jq -r '[.images[] | select(any(.repoTags[]?; endswith("/la-receta:1.0")))][0].repoTags[0]')
LO_QUE_SIRVE_LA_CARTA=$($K -n la-cocina exec "$POD" -- wget -qO- 127.0.0.1:8080/index.html | tr -d '\r' | head -1)
EOF
cat "$D/01-respuesta.txt"
