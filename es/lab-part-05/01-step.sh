#!/usr/bin/env bash
# lab-part-05 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p05
K="kubectl --kubeconfig $HOME/ckad-lab/p05/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de
BB=busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K -n la-plazoleta create deployment cocina-central --image=$IMG --replicas=3 --port=80
$K -n la-plazoleta rollout status deploy/cocina-central --timeout=300s
$K -n la-plazoleta get pods -l app=cocina-central -o wide

$K -n la-plazoleta expose deployment cocina-central \
  --name=domicilios --port=80 --target-port=80

$K -n la-plazoleta get svc domicilios
$K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios

$K -n la-plazoleta run el-mensajero --image=$BB --command -- sleep 36000
$K -n la-plazoleta wait --for=condition=Ready pod/el-mensajero --timeout=300s

$K -n la-plazoleta exec el-mensajero -- nslookup domicilios.la-plazoleta.svc.cluster.local

$K -n la-plazoleta get svc domicilios -o jsonpath='{.spec.clusterIP}{"\n"}'

$K -n la-plazoleta exec el-mensajero -- \
  wget -q -T 8 -O- http://domicilios.la-plazoleta.svc.cluster.local/ | head -4

# The answer file the lab asks you to type, written from the live cluster:
FQDN=domicilios.la-plazoleta.svc.cluster.local
cat > 01-respuesta.txt <<EOF
NOMBRE_COMPLETO=$FQDN
CLUSTERIP_POR_DNS=$($K -n la-plazoleta exec el-mensajero -- nslookup "$FQDN" | tr -d '\r' | awk -F'[ \t]+' '/^Address:/{print $2}' | grep -vE '[#:]' | head -1)
ENDPOINTS_LISTOS=$($K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios -o jsonpath='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}' | grep -c .)
EOF
cat 01-respuesta.txt
