#!/usr/bin/env bash
# lab-part-05 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p05
K="kubectl --kubeconfig $HOME/ckad-lab/p05/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de
BB=busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K -n la-galeria run el-local-de-jugos       --image=$IMG --labels=rol=local        --port=80
$K -n la-galeria run el-mensajero-con-carnet --image=$BB  --labels=acceso=permitido --command -- sleep 36000
$K -n la-galeria run el-vendedor-ambulante   --image=$BB  --labels=acceso=negado    --command -- sleep 36000
$K -n la-galeria wait --for=condition=Ready pod --all --timeout=300s

DESTINO=$($K -n la-galeria get pod el-local-de-jugos -o jsonpath='{.status.podIP}')
echo "el local de jugos vive en $DESTINO"

echo "--- LINEA BASE, sin ninguna politica ---"
$K -n la-galeria exec el-mensajero-con-carnet -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "con carnet antes: $?"
$K -n la-galeria exec el-vendedor-ambulante -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "sin carnet antes: $?"

cat > politicas.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: negar-todo-lo-que-entra
  namespace: la-galeria
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dejar-entrar-al-mensajero
  namespace: la-galeria
spec:
  podSelector:
    matchLabels:
      rol: local
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          acceso: permitido
    ports:
    - protocol: TCP
      port: 80
YAML

$K apply -f politicas.yaml
$K -n la-galeria get networkpolicies
sleep 8

echo "--- DESPUES DE PONER LA REGLA ---"
$K -n la-galeria exec el-mensajero-con-carnet -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "con carnet despues: $?"
$K -n la-galeria exec el-vendedor-ambulante -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
echo "sin carnet despues: $?"

# The answer file the lab asks you to type, measured again after the policies:
$K -n la-galeria exec el-mensajero-con-carnet -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
CON=$?
$K -n la-galeria exec el-vendedor-ambulante -- wget -q -T 5 -O- "http://$DESTINO" >/dev/null 2>&1
SIN=$?
cat > 03-respuesta.txt <<EOF
SALIDA_CON_CARNET=$CON
SALIDA_SIN_CARNET=$SIN
EOF
cat 03-respuesta.txt
