#!/usr/bin/env bash
# lab-part-03 step 1 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. El termometro: quien esta reiniciando y cuantas veces.
$K -n la-panaderia get pods
$K -n la-panaderia get pod -l app=horno \
  -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}{"\n"}'

# 2. La historia clinica: el kubelet deja escrito que intento y por que no pudo.
$K -n la-panaderia describe pod -l app=horno | tail -14
$K -n la-panaderia get events --field-selector reason=Unhealthy \
  -o jsonpath='{range .items[*]}{.reason}{"\t"}{.message}{"\n"}{end}'

# 3. Los examenes: a que puerto llama la sonda y que puerto atiende el contenedor.
$K -n la-panaderia get deploy horno \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}{"\n"}'
$K -n la-panaderia get deploy horno \
  -o jsonpath='{range .spec.template.spec.containers[0].ports[*]}{.name}{"\t"}{.containerPort}{"\n"}{end}'

# 4. Recetar: la sonda de vida llama al puerto que el contenedor SI atiende.
#    Se deja como httpGet, que es lo que hay que respetar; solo cambia el numero.
#    Aqui se usa el nombre del puerto, que es la forma que no se desincroniza.
$K -n la-panaderia patch deployment horno --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/port","value":"http"}]'

# 5. Alta medica: el rollout termina y el contador de reinicios deja de subir.
$K -n la-panaderia rollout status deployment/horno --timeout=240s
sleep 45
$K -n la-panaderia get pods

# The answer file the lab asks you to type, written from the live cluster:
EVT=$($K -n la-panaderia get events --field-selector reason=Unhealthy \
  -o jsonpath='{range .items[*]}{.reason}{"|"}{.message}{"\n"}{end}' | grep -m1 '|Liveness probe failed')
cat > "$W/01-respuesta.txt" <<EOF
PUERTO_SONDA=$(echo "$EVT" | sed -n 's|.*http://[^:]*:\([0-9]*\)/.*|\1|p')
PUERTO_REAL=$($K -n la-panaderia get deploy horno -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')
RAZON_EVENTO=${EVT%%|*}
EOF
cat "$W/01-respuesta.txt"
