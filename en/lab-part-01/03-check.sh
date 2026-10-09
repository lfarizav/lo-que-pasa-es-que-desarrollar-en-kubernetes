#!/usr/bin/env bash
# lab-part-01 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-ckad-p01"
NS=la-madrugada
test -f "$D/03-respuesta.txt" || exit 1
PAN=$($K -n $NS get cronjob el-pan-de-la-madrugada -o json 2>/dev/null)
test -n "$PAN" || exit 1
test "$(echo "$PAN" | jq -r '.kind')" = "CronJob" || exit 1
HORARIO=$(echo "$PAN" | jq -r '.spec.schedule // empty')
HIST_OK=$(echo "$PAN" | jq -r '.spec.successfulJobsHistoryLimit // empty')
HIST_MAL=$(echo "$PAN" | jq -r '.spec.failedJobsHistoryLimit // empty')
test "$HORARIO" = "*/1 * * * *" || exit 1
test "$HIST_OK" = "2" || exit 1
test "$HIST_MAL" = "1" || exit 1
test "$(echo "$PAN" | jq -r '.spec.suspend // false')" = "false" || exit 1
grep -qxF "HORARIO_DEL_PAN=$HORARIO" "$D/03-respuesta.txt" || exit 1
grep -qxF "HISTORIAL_DE_EXITOSOS=$HIST_OK" "$D/03-respuesta.txt" || exit 1
echo "$PAN" | jq -e '.status.lastScheduleTime != null' >/dev/null || exit 1
IDPAN=$(echo "$PAN" | jq -r '.metadata.uid')
EMPLEOS=$($K -n $NS get jobs -o json 2>/dev/null)
MIOS=$(echo "$EMPLEOS" | jq -c --arg u "$IDPAN" '[.items[] | select(.metadata.deletionTimestamp == null) | select(any(.metadata.ownerReferences[]?; .kind == "CronJob" and .uid == $u))]')
test "$(echo "$MIOS" | jq 'length')" -ge 1 || exit 1
DUENO=$(echo "$MIOS" | jq -r '.[0].metadata.ownerReferences[0].kind')
test "$DUENO" = "CronJob" || exit 1
grep -qxF "DUENO_DE_LOS_EMPLEOS=$DUENO" "$D/03-respuesta.txt" || exit 1
HORNEADAS=$(echo "$MIOS" | jq '[.[] | select((.status.succeeded // 0) >= 1)] | length')
test "$HORNEADAS" -ge 1 || exit 1
test "$HORNEADAS" -le "$((HIST_OK + 1))" || exit 1
SUELTOS=$(echo "$EMPLEOS" | jq '[.items[] | select(.metadata.deletionTimestamp == null) | select((.metadata.ownerReferences // []) | length == 0)] | length')
test "$SUELTOS" = "0" || exit 1
echo ok
