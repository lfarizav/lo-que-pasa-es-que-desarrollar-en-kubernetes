#!/usr/bin/env bash
# lab-part-02 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p02
KC="$HOME/ckad-lab/p02/kubeconfig"

export HELM_CONFIG_HOME="$HOME/ckad-lab/p02/helm"
export HELM_CACHE_HOME="$HOME/ckad-lab/p02/helm/cache"
export HELM_DATA_HOME="$HOME/ckad-lab/p02/helm/data"
export HELM_REPOSITORY_CONFIG="$HOME/ckad-lab/p02/helm/repositories.yaml"
export HELM_REPOSITORY_CACHE="$HOME/ckad-lab/p02/helm/cache"

helm version

helm repo add podinfo https://stefanprodan.github.io/podinfo
helm repo update

helm search repo podinfo --versions | head -5

helm show chart podinfo/podinfo --version 6.13.0 | grep -E '^(name|version|appVersion):'

helm install franquicia-del-barrio podinfo/podinfo \
  --version 6.13.0 \
  --namespace la-franquicia --create-namespace \
  --set replicaCount=3 \
  --set ui.message="lo que pasa es que aqui si atienden" \
  --kubeconfig "$KC" --wait --timeout 5m

helm list -n la-franquicia -o json --kubeconfig "$KC"
helm get values franquicia-del-barrio -n la-franquicia -o json --kubeconfig "$KC"

kubectl --kubeconfig "$KC" -n la-franquicia get secret -l owner=helm,name=franquicia-del-barrio \
  -o custom-columns='SECRETO:.metadata.name,VERSION:.metadata.labels.version,ESTADO:.metadata.labels.status'

kubectl --kubeconfig "$KC" -n la-franquicia get deployment franquicia-del-barrio-podinfo \
  -o jsonpath='imagen={.spec.template.spec.containers[0].image}{"\n"}listas={.status.readyReplicas}{"\n"}'

kubectl --kubeconfig "$KC" -n la-franquicia run mi-sonda \
  --image=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236 \
  --restart=Never --command -- sleep 900
kubectl --kubeconfig "$KC" -n la-franquicia wait --for=condition=Ready pod/mi-sonda --timeout=300s
kubectl --kubeconfig "$KC" -n la-franquicia exec mi-sonda -- \
  wget -qO- http://franquicia-del-barrio-podinfo:9898/
kubectl --kubeconfig "$KC" -n la-franquicia delete pod mi-sonda

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $KC"
$K -n la-franquicia run mi-sonda \
  --image=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236 \
  --restart=Never --command -- sleep 300
$K -n la-franquicia wait --for=condition=Ready pod/mi-sonda --timeout=300s
CUERPO=$($K -n la-franquicia exec mi-sonda -- wget -qO- http://franquicia-del-barrio-podinfo:9898/)
$K -n la-franquicia delete pod mi-sonda --wait=false
cat > "$D/04-respuesta.txt" <<EOF
VERSION_DEL_CHART=$(helm list -n la-franquicia --kubeconfig "$KC" -o json | sed -n 's/.*"chart":"podinfo-\([^"]*\)".*/\1/p')
MENSAJE_VIVO=$(echo "$CUERPO" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p')
REPLICAS_LISTAS=$($K -n la-franquicia get deployment franquicia-del-barrio-podinfo -o jsonpath='{.status.readyReplicas}')
EOF
cat "$D/04-respuesta.txt"
