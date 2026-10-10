#!/usr/bin/env bash
# lab-part-02 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p02
KC="$HOME/ckad-lab/p02/kubeconfig"

VIEJA=nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10
MEDIA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
NUEVA=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

kubectl --kubeconfig "$KC" -n el-restaurante create deployment carta-de-la-semana \
  --image="$VIEJA" --replicas=3
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/carta-de-la-semana --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante set image deployment/carta-de-la-semana nginx="$MEDIA"
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/carta-de-la-semana --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante set image deployment/carta-de-la-semana nginx="$NUEVA"
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/carta-de-la-semana --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante rollout history deployment/carta-de-la-semana

kubectl --kubeconfig "$KC" -n el-restaurante rollout undo deployment/carta-de-la-semana --to-revision=2
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/carta-de-la-semana --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante rollout history deployment/carta-de-la-semana

kubectl --kubeconfig "$KC" -n el-restaurante get deployment carta-de-la-semana \
  -o jsonpath='rev={.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}imagen={.spec.template.spec.containers[0].image}{"\n"}listas={.status.readyReplicas}{"\n"}'

kubectl --kubeconfig "$KC" -n el-restaurante get rs -l app=carta-de-la-semana \
  -o custom-columns='NOMBRE:.metadata.name,REV:.metadata.annotations.deployment\.kubernetes\.io/revision,IMAGEN:.spec.template.spec.containers[0].image,DESEADAS:.spec.replicas'

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $KC"
UID_DEP=$($K -n el-restaurante get deployment carta-de-la-semana -o jsonpath='{.metadata.uid}')
cat > "$D/02-respuesta.txt" <<EOF
REVISION_FINAL=$($K -n el-restaurante get deployment carta-de-la-semana -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
IMAGEN_VIVA=$($K -n el-restaurante get deployment carta-de-la-semana -o jsonpath='{.spec.template.spec.containers[0].image}')
REVISIONES_VIVAS=$($K -n el-restaurante get rs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].uid}{"|"}{.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}{end}' | grep "^$UID_DEP|" | cut -d'|' -f2 | sort -n | paste -sd, -)
EOF
cat "$D/02-respuesta.txt"
