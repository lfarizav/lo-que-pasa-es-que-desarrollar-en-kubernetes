#!/usr/bin/env bash
# lab-part-01 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-ckad-p01"
NS=los-encargos
test -f "$D/02-respuesta.txt" || exit 1
EMPLEO=$($K -n $NS get job los-encargos-del-almuerzo -o json 2>/dev/null)
test -n "$EMPLEO" || exit 1
test "$(echo "$EMPLEO" | jq -r '.kind')" = "Job" || exit 1
ENCARGOS=$(echo "$EMPLEO" | jq -r '.spec.completions // empty')
REINTENTOS=$(echo "$EMPLEO" | jq -r '.spec.backoffLimit // empty')
EXITOSOS=$(echo "$EMPLEO" | jq -r '.status.succeeded // 0')
test "$ENCARGOS" = "6" || exit 1
test "$REINTENTOS" = "2" || exit 1
test "$EXITOSOS" = "$ENCARGOS" || exit 1
echo "$EMPLEO" | jq -e '[.status.conditions[]? | select(.type == "Complete" and .status == "True")] | length == 1' >/dev/null || exit 1
grep -qxF "ENCARGOS_COMPLETADOS=$EXITOSOS" "$D/02-respuesta.txt" || exit 1
grep -qxF "REINTENTOS_PERMITIDOS=$REINTENTOS" "$D/02-respuesta.txt" || exit 1
PODS=$($K -n $NS get pods -o json 2>/dev/null | jq -c '[.items[] | select(.metadata.deletionTimestamp == null)]')
test "$(echo "$PODS" | jq 'length')" -ge 1 || exit 1
DUENOS=$(echo "$PODS" | jq -r '[.[].metadata.ownerReferences[0].kind // "ninguno"] | unique | join(" ")')
test "$DUENOS" = "Job" || exit 1
grep -qxF "DUENO_DE_LOS_PODS=$DUENOS" "$D/02-respuesta.txt" || exit 1
test "$(echo "$PODS" | jq '[.[] | select(.status.phase == "Succeeded")] | length')" -ge "$ENCARGOS" || exit 1
for TIPO in deployments replicasets statefulsets daemonsets; do
  test "$($K -n $NS get "$TIPO" -o json 2>/dev/null | jq '.items | length')" = "0" || exit 1
done
echo ok
