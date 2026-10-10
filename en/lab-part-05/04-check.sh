#!/usr/bin/env bash
# lab-part-05 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p05"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/04-respuesta.txt" || exit 1
CLASE=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
test "$CLASE" = "nginx" || exit 1
$K get ingressclass "$CLASE" -o jsonpath='{.spec.controller}' 2>/dev/null | grep -qx 'k8s.io/ingress-nginx' || exit 1
$K -n ingress-nginx get deploy ingress-nginx-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -qE '^[1-9][0-9]*$' || exit 1
HOST=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
test -n "$HOST" || exit 1
BROPA=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/ropa")].backend.service.name}' 2>/dev/null)
BHEL=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.rules[0].http.paths[?(@.path=="/helados")].backend.service.name}' 2>/dev/null)
test "$BROPA" = "local-de-ropa" || exit 1
test "$BHEL" = "local-de-helados" || exit 1
for SVC in "$BROPA" "$BHEL"; do
  $K -n el-centro-comercial get endpointslices -l "kubernetes.io/service-name=$SVC" -o jsonpath="$JP_LISTOS" 2>/dev/null | grep -q . || exit 1
done
RROPA=""
RHEL=""
for _ in $(seq 1 30); do
  RROPA=$(curl -sS --max-time 15 -H "Host: $HOST" "http://localhost:8085/ropa/" 2>/dev/null)
  RHEL=$(curl -sS --max-time 15 -H "Host: $HOST" "http://localhost:8085/helados/" 2>/dev/null)
  echo "$RROPA" | grep -qF "LOCAL DE ROPA" && echo "$RHEL" | grep -qF "LOCAL DE HELADOS" && break
  sleep 2
done
echo "$RROPA" | grep -qF "LOCAL DE ROPA" || exit 1
echo "$RHEL" | grep -qF "LOCAL DE HELADOS" || exit 1
CODIGO=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 -H "Host: no-existe-este-centro.local" "http://localhost:8085/ropa/" 2>/dev/null)
grep -qxF "CLASE_DEL_DIRECTORIO=$CLASE" "$D/04-respuesta.txt" || exit 1
grep -qxF "HOST_DEL_DIRECTORIO=$HOST" "$D/04-respuesta.txt" || exit 1
grep -qxF "HTTP_HOST_DESCONOCIDO=$CODIGO" "$D/04-respuesta.txt" || exit 1
echo ok
