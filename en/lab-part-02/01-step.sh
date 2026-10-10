#!/usr/bin/env bash
# lab-part-02 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p02
KC="$HOME/ckad-lab/p02/kubeconfig"

MEDIA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
NUEVA=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

cat > turno-de-almuerzo.yaml <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: turno-de-almuerzo
  namespace: el-restaurante
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: turno-de-almuerzo
  template:
    metadata:
      labels:
        app: turno-de-almuerzo
    spec:
      containers:
      - name: nginx
        image: $MEDIA
        resources:
          requests:
            cpu: 20m
            memory: 24Mi
YAML

kubectl --kubeconfig "$KC" apply -f turno-de-almuerzo.yaml
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/turno-de-almuerzo --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante get deployment turno-de-almuerzo \
  -o jsonpath='tipo={.spec.strategy.type}{"\n"}surge={.spec.strategy.rollingUpdate.maxSurge}{"\n"}nodisp={.spec.strategy.rollingUpdate.maxUnavailable}{"\n"}'

kubectl --kubeconfig "$KC" -n el-restaurante set image deployment/turno-de-almuerzo nginx="$NUEVA"
kubectl --kubeconfig "$KC" -n el-restaurante rollout status deployment/turno-de-almuerzo --timeout=300s

kubectl --kubeconfig "$KC" -n el-restaurante get deployment turno-de-almuerzo \
  -o jsonpath='listas={.status.readyReplicas}{"\n"}actualizadas={.status.updatedReplicas}{"\n"}disponibles={.status.availableReplicas}{"\n"}imagen={.spec.template.spec.containers[0].image}{"\n"}'

kubectl --kubeconfig "$KC" -n el-restaurante get rs -l app=turno-de-almuerzo \
  -o custom-columns='NOMBRE:.metadata.name,REV:.metadata.annotations.deployment\.kubernetes\.io/revision,IMAGEN:.spec.template.spec.containers[0].image,DESEADAS:.spec.replicas'

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $KC"
cat > "$D/01-respuesta.txt" <<EOF
MAX_SURGE=$($K -n el-restaurante get deployment turno-de-almuerzo -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}')
MAX_UNAVAILABLE=$($K -n el-restaurante get deployment turno-de-almuerzo -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')
REPLICAS_LISTAS=$($K -n el-restaurante get deployment turno-de-almuerzo -o jsonpath='{.status.readyReplicas}')
EOF
cat "$D/01-respuesta.txt"
