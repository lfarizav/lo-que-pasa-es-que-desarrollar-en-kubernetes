#!/usr/bin/env bash
# lab-part-03 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/02-respuesta.txt"
CURL="curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17"
test -f "$R" || exit 1
grep -qxF "RUTA_SONDA=/abierto" "$R" || exit 1
grep -qxF "CODIGO_HTTP=404" "$R" || exit 1
grep -qxF "TIPO_DE_SONDA=readinessProbe" "$R" || exit 1
test "$($K -n la-tienda get deploy mostrador -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "2" || exit 1
$K -n la-tienda rollout status deployment/mostrador --timeout=180s >/dev/null 2>&1 || exit 1
test "$($K -n la-tienda get deploy mostrador -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" || exit 1
SONDA=$($K -n la-tienda get deploy mostrador -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)
test -n "$SONDA" || exit 1
if [ "$SONDA" != "8080" ]; then
  CP=$($K -n la-tienda get deploy mostrador -o jsonpath="{.spec.template.spec.containers[0].ports[?(@.name=='$SONDA')].containerPort}" 2>/dev/null)
  test "$CP" = "8080" || exit 1
fi
test "$($K -n la-tienda get svc domicilios -o jsonpath='{.spec.selector.app}' 2>/dev/null)" = "mostrador" || exit 1
CONVERGIO=no
for i in 1 2 3 4 5 6; do
  LISTOS=$($K -n la-tienda get endpointslice -l kubernetes.io/service-name=domicilios \
    -o jsonpath='{range .items[*].endpoints[*]}{.conditions.ready}{"\n"}{end}' 2>/dev/null | grep -c '^true$')
  IPS=$($K -n la-tienda get pod -l app=mostrador -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
  EPS=$($K -n la-tienda get endpointslice -l kubernetes.io/service-name=domicilios \
    -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
  if [ "$LISTOS" -eq 2 ] && [ "$IPS" = "$EPS" ]; then CONVERGIO=si; break; fi
  sleep 5
done
test "$CONVERGIO" = "si" || exit 1
$K -n default get pod mandadero >/dev/null 2>&1 || \
  $K -n default run mandadero --image="$CURL" --restart=Never --command -- sleep 86400 >/dev/null 2>&1
$K -n default wait --for=condition=Ready pod/mandadero --timeout=300s >/dev/null 2>&1 || exit 1
COD=""
for i in 1 2 3 4 5 6; do
  COD=$($K -n default exec mandadero -- curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
    http://domicilios.la-tienda.svc.cluster.local/ 2>/dev/null)
  [ "$COD" = "200" ] && break
  sleep 5
done
test "$COD" = "200" || exit 1
echo ok
