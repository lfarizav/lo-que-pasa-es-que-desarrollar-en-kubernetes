#!/usr/bin/env bash
# lab-part-03 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/01-respuesta.txt"
test -f "$R" || exit 1
grep -qxF "PUERTO_SONDA=8081" "$R" || exit 1
grep -qxF "PUERTO_REAL=8080" "$R" || exit 1
grep -qxF "RAZON_EVENTO=Unhealthy" "$R" || exit 1
test "$($K -n la-panaderia get deploy horno -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "1" || exit 1
$K -n la-panaderia rollout status deployment/horno --timeout=180s >/dev/null 2>&1 || exit 1
test "$($K -n la-panaderia get deploy horno -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" || exit 1
SONDA=$($K -n la-panaderia get deploy horno -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null)
test -n "$SONDA" || exit 1
if [ "$SONDA" != "8080" ]; then
  CP=$($K -n la-panaderia get deploy horno -o jsonpath="{.spec.template.spec.containers[0].ports[?(@.name=='$SONDA')].containerPort}" 2>/dev/null)
  test "$CP" = "8080" || exit 1
fi
POD=""
for p in $($K -n la-panaderia get pod -l app=horno -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  LISTO=$($K -n la-panaderia get pod "$p" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  MUERE=$($K -n la-panaderia get pod "$p" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)
  if [ "$LISTO" = "True" ] && [ -z "$MUERE" ]; then POD="$p"; break; fi
done
test -n "$POD" || exit 1
$K -n la-panaderia exec "$POD" -- wget -q -T 5 -O - http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1
A=$($K -n la-panaderia get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
test -n "$A" || exit 1
sleep 45
B=$($K -n la-panaderia get pod "$POD" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
test -n "$B" || exit 1
test "$A" = "$B" || exit 1
test "$($K -n la-panaderia get pod "$POD" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = "True" || exit 1
echo ok
