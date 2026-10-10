#!/usr/bin/env bash
# lab-part-03 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/04-respuesta.txt"
test -f "$R" || exit 1
grep -qxF "APIVERSION_MUERTA=batch/v1beta1" "$R" || exit 1
grep -qxF "APIVERSION_VIVA=batch/v1" "$R" || exit 1
grep -qxF "VERSION_QUE_LA_RETIRO=v1.25" "$R" || exit 1
AV=$($K -n el-deposito get cronjob conteo-inventario -o jsonpath='{.apiVersion}' 2>/dev/null)
test "$AV" = "batch/v1" || exit 1
test "$($K -n el-deposito get cronjob conteo-inventario -o jsonpath='{.spec.schedule}' 2>/dev/null)" = "* * * * *" || exit 1
SUS=$($K -n el-deposito get cronjob conteo-inventario -o jsonpath='{.spec.suspend}' 2>/dev/null)
test "$SUS" != "true" || exit 1
UID_CJ=$($K -n el-deposito get cronjob conteo-inventario -o jsonpath='{.metadata.uid}' 2>/dev/null)
test -n "$UID_CJ" || exit 1
JOB=""; MEJOR=""
for j in $($K -n el-deposito get jobs -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  OW=$($K -n el-deposito get job "$j" -o jsonpath='{.metadata.ownerReferences[0].uid}' 2>/dev/null)
  OK=$($K -n el-deposito get job "$j" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null)
  SU=$($K -n el-deposito get job "$j" -o jsonpath='{.status.succeeded}' 2>/dev/null)
  CT=$($K -n el-deposito get job "$j" -o jsonpath='{.status.completionTime}' 2>/dev/null)
  if [ "$OW" = "$UID_CJ" ] && [ "$OK" = "CronJob" ] && [ "${SU:-0}" -ge 1 ] && [ -n "$CT" ]; then
    if [ -z "$MEJOR" ] || [ "$CT" \> "$MEJOR" ]; then MEJOR="$CT"; JOB="$j"; fi
  fi
done
test -n "$JOB" || exit 1
POD=$($K -n el-deposito get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$POD" || exit 1
$K -n el-deposito logs "$POD" 2>/dev/null | grep -qF "conteo terminado" || exit 1
echo ok
