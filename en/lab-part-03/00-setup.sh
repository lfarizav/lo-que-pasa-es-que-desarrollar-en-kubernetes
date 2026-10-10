#!/usr/bin/env bash
# lab-part-03 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

set -e
W="$HOME/ckad-lab/p03"
KC="$W/kubeconfig"
K="kubectl --kubeconfig $KC"
NODO="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
CURL="curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17"

for t in kind kubectl docker base64; do
  command -v "$t" >/dev/null 2>&1 || { echo "FALTA: $t - instalelo antes de empezar."; exit 1; }
done

mkdir -p "$W"
# El kubeconfig es PRIVADO desde el primer comando: nunca se toca el
# ~/.kube/config de la maquina, y ningun otro cluster corre riesgo.
kind delete cluster --name ckad-p03 --kubeconfig "$KC" >/dev/null 2>&1 || true
kind create cluster --name ckad-p03 --kubeconfig "$KC" --image "$NODO" --wait 300s
chmod 600 "$KC"
$K wait --for=condition=Ready nodes --all --timeout=300s

# ------------------------------------------------------- sonda del catalogo
# El Paso 4 asume que este API server YA NO SIRVE batch/v1beta1. Eso se mide y
# nunca se supone: un objeto puede ser aceptado por un API server y rechazado
# por otro. Si este cluster todavia sirviera la version vieja, el Paso 4 seria
# pura decoracion y el montaje se detiene con un error con nombre.
$K api-versions | grep -qx 'batch/v1' || { echo "ERROR SONDA-BATCH-V1-AUSENTE: este cluster no sirve batch/v1 y el Paso 4 no tiene piso."; exit 1; }
if $K api-versions | grep -qx 'batch/v1beta1'; then
  echo "ERROR SONDA-API-VIEJA-VIVA: este API server todavia sirve batch/v1beta1."
  echo "El Paso 4 de este laboratorio seria decoracion, asi que el montaje se detiene aqui."
  exit 1
fi
echo "sonda-catalogo: batch/v1 vivo y batch/v1beta1 retirado; el Paso 4 tiene piso."

# Pod cliente: la herramienta con la que usted (y las comprobaciones) llaman a
# los Services desde adentro del cluster. No es una averia, es el telefono.
$K -n default run mandadero --image="$CURL" --restart=Never --command -- sleep 86400 >/dev/null
$K -n default wait --for=condition=Ready pod/mandadero --timeout=300s >/dev/null

# ------------------------------------------------------- las cuatro averias
# Las averias llegan codificadas en base64 A PROPOSITO. Eso no es criptografia
# y no pretende serlo: es una venda de cortesia, para que usted no lea la falla
# en el mismo script que la aplica. La respuesta completa de cada paso esta en
# el campo cmd de ese paso. La averia es identica para todo el mundo en todas
# las corridas.
mkdir -p "$W/averias" "$W/inventario"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGxhLXBhbmFkZXJpYQotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IGhvcm5vCiAgbmFtZXNwYWNlOiBsYS1wYW5hZGVyaWEKICBsYWJlbHM6CiAgICBhcHA6IGhvcm5vCnNwZWM6CiAgcmVwbGljYXM6IDEKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBhcHA6IGhvcm5vCiAgdGVtcGxhdGU6CiAgICBtZXRhZGF0YToKICAgICAgbGFiZWxzOgogICAgICAgIGFwcDogaG9ybm8KICAgIHNwZWM6CiAgICAgIGNvbnRhaW5lcnM6CiAgICAgIC0gbmFtZTogaG9ybm8KICAgICAgICBpbWFnZTogYnVzeWJveEBzaGEyNTY6OWRiN2I1OTk3OWMzODU1NWEzOWRlZjg0YTMxZmI5OGI1Mjk2OTUyZjllM2FmZDRmNmYxMWYwNWIwN2FkZmFiMAogICAgICAgIGNvbW1hbmQ6CiAgICAgICAgLSBzaAogICAgICAgIC0gLWMKICAgICAgICAtICJta2RpciAtcCAvd3d3ICYmIGVjaG8gJ3BhbiBjYWxpZW50ZScgPiAvd3d3L2luZGV4Lmh0bWwgJiYgZXhlYyBodHRwZCAtZiAtcCA4MDgwIC1oIC93d3ciCiAgICAgICAgcG9ydHM6CiAgICAgICAgLSBjb250YWluZXJQb3J0OiA4MDgwCiAgICAgICAgICBuYW1lOiBodHRwCiAgICAgICAgbGl2ZW5lc3NQcm9iZToKICAgICAgICAgIGh0dHBHZXQ6CiAgICAgICAgICAgIHBhdGg6IC8KICAgICAgICAgICAgcG9ydDogODA4MQogICAgICAgICAgaW5pdGlhbERlbGF5U2Vjb25kczogNQogICAgICAgICAgcGVyaW9kU2Vjb25kczogNQogICAgICAgICAgZmFpbHVyZVRocmVzaG9sZDogMgo=' \
  | base64 -d > "$W/averias/paso1.yaml"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGxhLXRpZW5kYQotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IG1vc3RyYWRvcgogIG5hbWVzcGFjZTogbGEtdGllbmRhCiAgbGFiZWxzOgogICAgYXBwOiBtb3N0cmFkb3IKc3BlYzoKICByZXBsaWNhczogMgogIHNlbGVjdG9yOgogICAgbWF0Y2hMYWJlbHM6CiAgICAgIGFwcDogbW9zdHJhZG9yCiAgdGVtcGxhdGU6CiAgICBtZXRhZGF0YToKICAgICAgbGFiZWxzOgogICAgICAgIGFwcDogbW9zdHJhZG9yCiAgICBzcGVjOgogICAgICBjb250YWluZXJzOgogICAgICAtIG5hbWU6IG1vc3RyYWRvcgogICAgICAgIGltYWdlOiBidXN5Ym94QHNoYTI1Njo5ZGI3YjU5OTc5YzM4NTU1YTM5ZGVmODRhMzFmYjk4YjUyOTY5NTJmOWUzYWZkNGY2ZjExZjA1YjA3YWRmYWIwCiAgICAgICAgY29tbWFuZDoKICAgICAgICAtIHNoCiAgICAgICAgLSAtYwogICAgICAgIC0gIm1rZGlyIC1wIC93d3cgJiYgZWNobyAnbW9zdHJhZG9yIGF0ZW5kaWVuZG8nID4gL3d3dy9pbmRleC5odG1sICYmIGV4ZWMgaHR0cGQgLWYgLXAgODA4MCAtaCAvd3d3IgogICAgICAgIHBvcnRzOgogICAgICAgIC0gY29udGFpbmVyUG9ydDogODA4MAogICAgICAgICAgbmFtZTogaHR0cAogICAgICAgIHJlYWRpbmVzc1Byb2JlOgogICAgICAgICAgaHR0cEdldDoKICAgICAgICAgICAgcGF0aDogL2FiaWVydG8KICAgICAgICAgICAgcG9ydDogODA4MAogICAgICAgICAgaW5pdGlhbERlbGF5U2Vjb25kczogMwogICAgICAgICAgcGVyaW9kU2Vjb25kczogNQotLS0KYXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBuYW1lOiBkb21pY2lsaW9zCiAgbmFtZXNwYWNlOiBsYS10aWVuZGEKc3BlYzoKICBzZWxlY3RvcjoKICAgIGFwcDogbW9zdHJhZG9yCiAgcG9ydHM6CiAgLSBuYW1lOiBodHRwCiAgICBwcm90b2NvbDogVENQCiAgICBwb3J0OiA4MAogICAgdGFyZ2V0UG9ydDogODA4MAo=' \
  | base64 -d > "$W/averias/paso2.yaml"
printf '%s' 'YXBpVmVyc2lvbjogdjEKa2luZDogTmFtZXNwYWNlCm1ldGFkYXRhOgogIG5hbWU6IGVsLWNhdGFsb2dvCi0tLQphcGlWZXJzaW9uOiB2MQpraW5kOiBDb25maWdNYXAKbWV0YWRhdGE6CiAgbmFtZTogZWwtaW52ZW50YXJpbwogIG5hbWVzcGFjZTogZWwtY2F0YWxvZ28KZGF0YToKICBQQUdJTkFfQ0FUQUxPR086ICJlZGljaW9uLTIwMjYtMDgiCi0tLQphcGlWZXJzaW9uOiBhcHBzL3YxCmtpbmQ6IERlcGxveW1lbnQKbWV0YWRhdGE6CiAgbmFtZTogY2F0YWxvZ28KICBuYW1lc3BhY2U6IGVsLWNhdGFsb2dvCiAgbGFiZWxzOgogICAgYXBwOiBjYXRhbG9nbwpzcGVjOgogIHJlcGxpY2FzOiAxCiAgc2VsZWN0b3I6CiAgICBtYXRjaExhYmVsczoKICAgICAgYXBwOiBjYXRhbG9nbwogIHRlbXBsYXRlOgogICAgbWV0YWRhdGE6CiAgICAgIGxhYmVsczoKICAgICAgICBhcHA6IGNhdGFsb2dvCiAgICBzcGVjOgogICAgICB2b2x1bWVzOgogICAgICAtIG5hbWU6IGVzdGFkbwogICAgICAgIGVtcHR5RGlyOiB7fQogICAgICBjb250YWluZXJzOgogICAgICAtIG5hbWU6IGNhdGFsb2dvCiAgICAgICAgaW1hZ2U6IGJ1c3lib3hAc2hhMjU2OjlkYjdiNTk5NzljMzg1NTVhMzlkZWY4NGEzMWZiOThiNTI5Njk1MmY5ZTNhZmQ0ZjZmMTFmMDViMDdhZGZhYjAKICAgICAgICB2b2x1bWVNb3VudHM6CiAgICAgICAgLSBuYW1lOiBlc3RhZG8KICAgICAgICAgIG1vdW50UGF0aDogL2VzdGFkbwogICAgICAgIGVudjoKICAgICAgICAtIG5hbWU6IFBBR0lOQV9DQVRBTE9HTwogICAgICAgICAgdmFsdWVGcm9tOgogICAgICAgICAgICBjb25maWdNYXBLZXlSZWY6CiAgICAgICAgICAgICAgbmFtZTogZWwtaW52ZW50YXJpbwogICAgICAgICAgICAgIGtleTogUEFHSU5BX1ZJRUpBCiAgICAgICAgICAgICAgb3B0aW9uYWw6IHRydWUKICAgICAgICBjb21tYW5kOgogICAgICAgIC0gc2gKICAgICAgICAtIC1jCiAgICAgICAgLSB8CiAgICAgICAgICBpZiBbIC16ICIkUEFHSU5BX0NBVEFMT0dPIiBdOyB0aGVuCiAgICAgICAgICAgIGlmIFsgISAtZiAvZXN0YWRvL3F1ZWphIF07IHRoZW4KICAgICAgICAgICAgICB0b3VjaCAvZXN0YWRvL3F1ZWphCiAgICAgICAgICAgICAgZWNobyAiRkFUQUw6IFBBR0lOQV9DQVRBTE9HTyB2YWNpYSwgZWwgY2F0YWxvZ28gbm8gYWJyZSIKICAgICAgICAgICAgICBleGl0IDEKICAgICAgICAgICAgZmkKICAgICAgICAgICAgZXhlYyBzbGVlcCA4NjQwMAogICAgICAgICAgZmkKICAgICAgICAgIG1rZGlyIC1wIC93d3cKICAgICAgICAgIGVjaG8gImNhdGFsb2dvICRQQUdJTkFfQ0FUQUxPR08iID4gL3d3dy9pbmRleC5odG1sCiAgICAgICAgICBleGVjIGh0dHBkIC1mIC1wIDgwODAgLWggL3d3dwogICAgICAgIHBvcnRzOgogICAgICAgIC0gY29udGFpbmVyUG9ydDogODA4MAogICAgICAgICAgbmFtZTogaHR0cAotLS0KYXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBuYW1lOiBjYXRhbG9nbwogIG5hbWVzcGFjZTogZWwtY2F0YWxvZ28Kc3BlYzoKICBzZWxlY3RvcjoKICAgIGFwcDogY2F0YWxvZ28KICBwb3J0czoKICAtIG5hbWU6IGh0dHAKICAgIHByb3RvY29sOiBUQ1AKICAgIHBvcnQ6IDgwCiAgICB0YXJnZXRQb3J0OiA4MDgwCg==' \
  | base64 -d > "$W/averias/paso3.yaml"
printf '%s' 'YXBpVmVyc2lvbjogYmF0Y2gvdjFiZXRhMQpraW5kOiBDcm9uSm9iCm1ldGFkYXRhOgogIG5hbWU6IGNvbnRlby1pbnZlbnRhcmlvCiAgbmFtZXNwYWNlOiBlbC1kZXBvc2l0bwpzcGVjOgogIHNjaGVkdWxlOiAiKiAqICogKiAqIgogIHN1Y2Nlc3NmdWxKb2JzSGlzdG9yeUxpbWl0OiAzCiAgZmFpbGVkSm9ic0hpc3RvcnlMaW1pdDogMQogIGpvYlRlbXBsYXRlOgogICAgc3BlYzoKICAgICAgdGVtcGxhdGU6CiAgICAgICAgc3BlYzoKICAgICAgICAgIHJlc3RhcnRQb2xpY3k6IE9uRmFpbHVyZQogICAgICAgICAgY29udGFpbmVyczoKICAgICAgICAgIC0gbmFtZTogY29udGFkb3IKICAgICAgICAgICAgaW1hZ2U6IGJ1c3lib3hAc2hhMjU2OjlkYjdiNTk5NzljMzg1NTVhMzlkZWY4NGEzMWZiOThiNTI5Njk1MmY5ZTNhZmQ0ZjZmMTFmMDViMDdhZGZhYjAKICAgICAgICAgICAgY29tbWFuZDoKICAgICAgICAgICAgLSBzaAogICAgICAgICAgICAtIC1jCiAgICAgICAgICAgIC0gImVjaG8gY29udGVvIHRlcm1pbmFkbzogJChkYXRlIC11ICslRlQlVFopIgo=' \
  | base64 -d > "$W/inventario/conteo-inventario.yaml"

$K apply -f "$W/averias/paso1.yaml" >/dev/null
$K apply -f "$W/averias/paso2.yaml" >/dev/null
$K apply -f "$W/averias/paso3.yaml" >/dev/null
$K create namespace el-deposito >/dev/null

# El manifiesto del Paso 4 se aplica aqui y TIENE que ser rechazado. El error
# queda guardado en ~/ckad-lab/p03/inventario/apply-fallido.log para que
# usted lo lea con calma, y el manifiesto queda en el mismo directorio.
if $K apply -f "$W/inventario/conteo-inventario.yaml" > "$W/inventario/apply-fallido.log" 2>&1; then
  echo "ERROR SONDA-CRONJOB-VIEJO-ACEPTADO: el cluster acepto el manifiesto viejo."
  echo "El Paso 4 no tendria nada que diagnosticar, asi que el montaje se detiene aqui."
  exit 1
fi

# ------------------------------------ se espera a que las averias afloren
# Cada espera es ademas una sonda del sustrato: si el sintoma no aparece, el
# kubelet no esta haciendo lo que el paso da por hecho, y el montaje se detiene
# con un error con nombre en vez de entregarle un ejercicio sin piso.

# Paso 1: el kubelet TIENE que reiniciar el contenedor por la sonda de vida.
for i in $(seq 1 36); do
  P1=$($K -n la-panaderia get pod -l app=horno -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  [ -n "$P1" ] && [ "$P1" -ge 1 ] && break
  sleep 5
done
[ -n "$P1" ] && [ "$P1" -ge 1 ] || { echo "ERROR SONDA-LIVENESS-NO-REINICIA: el kubelet no reinicio el contenedor pese a fallar la sonda de vida."; exit 1; }

# Paso 2: los dos Pods corriendo y CERO direcciones listas en el Service.
$K -n la-tienda wait --for=jsonpath='{.status.phase}'=Running pod -l app=mostrador --timeout=300s >/dev/null
for i in $(seq 1 24); do
  L=$($K -n la-tienda get endpointslice -l kubernetes.io/service-name=domicilios -o jsonpath='{range .items[*].endpoints[*]}{.conditions.ready}{"\n"}{end}' 2>/dev/null | grep -c '^true$' || true)
  [ "${L:-0}" -eq 0 ] && break
  sleep 5
done
[ "${L:-0}" -eq 0 ] || { echo "ERROR SONDA-READINESS-NO-FILTRA: hay direcciones listas pese a que la sonda de disponibilidad falla."; exit 1; }

# Paso 3: el Pod queda Running con un reinicio y la queja guardada SOLO en la
# bitacora de la instancia anterior.
for i in $(seq 1 36); do
  P3=$($K -n el-catalogo get pod -l app=catalogo -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  [ -n "$P3" ] && [ "$P3" -ge 1 ] && break
  sleep 5
done
[ -n "$P3" ] && [ "$P3" -ge 1 ] || { echo "ERROR SONDA-CATALOGO-NO-REINICIA: el contenedor del catalogo no llego a reiniciarse."; exit 1; }
POD3=$($K -n el-catalogo get pod -l app=catalogo -o jsonpath='{.items[0].metadata.name}')
$K -n el-catalogo logs "$POD3" --previous 2>/dev/null | grep -q 'FATAL' || { echo "ERROR SONDA-LOGS-PREVIOS: la bitacora de la instancia anterior no quedo disponible."; exit 1; }

echo "kubeconfig privado del laboratorio: $KC"
echo "USE --kubeconfig $KC EN TODOS SUS COMANDOS kubectl."
$K get pods -A -o wide | grep -E 'la-panaderia|la-tienda|el-catalogo|mandadero' || true
$K -n el-deposito get cronjobs 2>&1 | head -2
echo "montaje listo: el cluster ckad-p03 quedo con cuatro averias puestas."
