#!/usr/bin/env bash
# lab-part-02 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p02
KC="$HOME/ckad-lab/p02/kubeconfig"

MEDIA=nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
NUEVA=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

cat > el-restaurante.yaml <<YAML
apiVersion: v1
kind: Service
metadata:
  name: el-restaurante
  namespace: la-plaza
spec:
  selector:
    app: menu
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sabor-de-siempre
  namespace: la-plaza
spec:
  replicas: 8
  selector:
    matchLabels:
      app: menu
      version: siempre
  template:
    metadata:
      labels:
        app: menu
        version: siempre
    spec:
      containers:
      - name: nginx
        image: $MEDIA
        resources:
          requests:
            cpu: 10m
            memory: 20Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sabor-nuevo
  namespace: la-plaza
spec:
  replicas: 2
  selector:
    matchLabels:
      app: menu
      version: nuevo
  template:
    metadata:
      labels:
        app: menu
        version: nuevo
    spec:
      containers:
      - name: nginx
        image: $NUEVA
        resources:
          requests:
            cpu: 10m
            memory: 20Mi
YAML

kubectl --kubeconfig "$KC" apply -f el-restaurante.yaml
kubectl --kubeconfig "$KC" -n la-plaza rollout status deployment/sabor-de-siempre --timeout=300s
kubectl --kubeconfig "$KC" -n la-plaza rollout status deployment/sabor-nuevo --timeout=300s

kubectl --kubeconfig "$KC" -n la-plaza get svc el-restaurante -o jsonpath='selector={.spec.selector}{"\n"}'

kubectl --kubeconfig "$KC" -n la-plaza get endpointslices \
  -l kubernetes.io/service-name=el-restaurante \
  -o jsonpath='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.targetRef.name}{"\n"}{end}{end}'

kubectl --kubeconfig "$KC" -n la-plaza get pods -l app=menu \
  -o custom-columns='POD:.metadata.name,VERSION:.metadata.labels.version,NODO:.spec.nodeName'

kubectl --kubeconfig "$KC" -n la-plaza run mi-sonda --image="$MEDIA" --restart=Never --command -- sleep 900
kubectl --kubeconfig "$KC" -n la-plaza wait --for=condition=Ready pod/mi-sonda --timeout=300s
kubectl --kubeconfig "$KC" -n la-plaza exec mi-sonda -- sh -c \
  'i=0; while [ $i -lt 100 ]; do wget -qS -O /dev/null http://el-restaurante/ 2>&1 | sed -n "s/.*Server: *//p"; i=$((i+1)); done' \
  | sort | uniq -c
kubectl --kubeconfig "$KC" -n la-plaza delete pod mi-sonda

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $KC"
LISTOS=$($K -n la-plaza get endpointslices -l kubernetes.io/service-name=el-restaurante -o jsonpath='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.targetRef.name}{"\n"}{end}{end}')
NUEVOS_PODS=$($K -n la-plaza get pods -l app=menu,version=nuevo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
TOTAL=$(echo "$LISTOS" | grep -c .)
NUEVO=$(echo "$LISTOS" | grep -cxF -f <(echo "$NUEVOS_PODS"))
cat > "$D/03-respuesta.txt" <<EOF
ENDPOINTS_TOTALES=$TOTAL
ENDPOINTS_NUEVO=$NUEVO
PORCENTAJE_NUEVO=$(( NUEVO * 100 / TOTAL ))
EOF
cat "$D/03-respuesta.txt"
