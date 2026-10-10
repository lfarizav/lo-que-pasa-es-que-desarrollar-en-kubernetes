#!/usr/bin/env bash
# lab-part-04 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

KC="$HOME/ckad-lab/p04/kubeconfig"
cd ~/ckad-lab/p04

kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o yaml | sed -n '/^spec:/,$p'
kubectl --kubeconfig "$KC" apply -f puesto-de-frutas.yaml

cat > puesto-de-frutas.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: puesto-de-frutas
  namespace: plaza
spec:
  containers:
  - name: frutas
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh","-c","sleep 86400"]
    resources:
      requests:
        cpu: 200m
        memory: 128Mi
      limits:
        cpu: 400m
        memory: 256Mi
YAML

kubectl --kubeconfig "$KC" apply -f puesto-de-frutas.yaml
kubectl --kubeconfig "$KC" -n plaza wait --for=condition=Ready pod/puesto-de-frutas --timeout=180s
kubectl --kubeconfig "$KC" -n plaza get pods
kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza \
  -o jsonpath='cupo_pedido_memoria={.spec.hard.requests\.memory}{"\n"}en_uso_memoria={.status.used.requests\.memory}{"\n"}'
kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-frutas \
  -o jsonpath='memoria_pedida_por_el_puesto={.spec.containers[0].resources.requests.memory}{"\n"}'
# The answer file the lab asks you to type, written from the live cluster:
K="kubectl --kubeconfig $KC"
cat > 01-respuesta.txt <<EOF
CUPO_DE_MEMORIA_PEDIDA=$($K -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard.requests\.memory}')
MEMORIA_PEDIDA_POR_EL_PUESTO=$($K -n plaza get pod puesto-de-frutas -o jsonpath='{.spec.containers[0].resources.requests.memory}')
EOF
cat 01-respuesta.txt
