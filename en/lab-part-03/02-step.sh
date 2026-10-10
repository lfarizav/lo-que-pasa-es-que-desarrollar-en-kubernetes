#!/usr/bin/env bash
# lab-part-03 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. El sintoma: dos Pods corriendo y ninguno listo.
$K -n la-tienda get pods
$K -n la-tienda get deploy mostrador

# 2. El directorio del Service: hay direcciones anotadas pero ninguna lista.
$K -n la-tienda get endpointslice -l kubernetes.io/service-name=domicilios \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\t"}{.conditions.ready}{"\n"}{end}'

# 3. La razon, escrita por el kubelet en los eventos.
$K -n la-tienda get events --field-selector reason=Unhealthy \
  -o jsonpath='{range .items[*]}{.message}{"\n"}{end}' | head -3

# 4. Que ruta esta pidiendo la sonda, y comprobarlo a mano contra un Pod.
$K -n la-tienda get deploy mostrador \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
IP=$($K -n la-tienda get pod -l app=mostrador -o jsonpath='{.items[0].status.podIP}')
$K -n default exec mandadero -- curl -s -o /dev/null -w 'ruta mala: %{http_code}\n' --max-time 8 "http://$IP:8080/abierto"
$K -n default exec mandadero -- curl -s -o /dev/null -w 'raiz:      %{http_code}\n' --max-time 8 "http://$IP:8080/"

# 5. Recetar: la sonda de disponibilidad pregunta por algo que la aplicacion
#    de verdad sirve. Se deja como httpGet contra el mismo puerto 8080.
$K -n la-tienda patch deployment mostrador --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'

# 6. Comprobar: dos Pods listos, dos direcciones listas y el domicilio llega.
$K -n la-tienda rollout status deployment/mostrador --timeout=240s
$K -n la-tienda get endpointslice -l kubernetes.io/service-name=domicilios \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\t"}{.conditions.ready}{"\n"}{end}'
$K -n default exec mandadero -- curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 \
  http://domicilios.la-tienda.svc.cluster.local/

# The answer file the lab asks you to type, written from the live cluster and from the
# manifest the setup applied (the fix overwrote the path in the live object):
IP=$($K -n la-tienda get pod -l app=mostrador -o jsonpath='{.items[0].status.podIP}')
RUTA=$(sed -n 's/^ *path: *//p' "$W/averias/paso2.yaml" | head -1)
cat > "$W/02-respuesta.txt" <<EOF
RUTA_SONDA=$RUTA
CODIGO_HTTP=$($K -n default exec mandadero -- curl -s -o /dev/null -w '%{http_code}' --max-time 8 "http://$IP:8080$RUTA")
TIPO_DE_SONDA=$(grep -o '[a-z]*Probe' "$W/averias/paso2.yaml" | head -1)
EOF
cat "$W/02-respuesta.txt"
