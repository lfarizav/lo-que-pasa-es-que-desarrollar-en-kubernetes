#!/usr/bin/env bash
# lab-part-04 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/ckad-lab/p04/kubeconfig"
D="$HOME/ckad-lab/p04"
test -f "$D/01-respuesta.txt" || exit 1
FASE=$(kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-frutas -o jsonpath='{.status.phase}' 2>/dev/null)
test "$FASE" = "Running" || exit 1
LISTO=$(kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-frutas -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
test "$LISTO" = "True" || exit 1
for CAMPO in requests.cpu requests.memory limits.cpu limits.memory; do
  TIPO=${CAMPO%%.*}
  REC=${CAMPO##*.}
  V=$(kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-frutas -o jsonpath="{.spec.containers[0].resources.$TIPO.$REC}" 2>/dev/null)
  test -n "$V" || exit 1
done
JUGOS=$(kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-jugos -o jsonpath='{.status.phase}' 2>/dev/null)
test "$JUGOS" = "Running" || exit 1
kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza >/dev/null 2>&1 || exit 1
DURO=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard.requests\.cpu}|{.spec.hard.requests\.memory}|{.spec.hard.limits\.cpu}|{.spec.hard.limits\.memory}|{.spec.hard.pods}' 2>/dev/null)
test "$DURO" = "1|1Gi|2|2Gi|8" || exit 1
ALCANCES=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.scopes[*]}{.spec.scopeSelector}' 2>/dev/null)
test -z "$ALCANCES" || exit 1
CUOTAS=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null)
test "$CUOTAS" = "cupo-de-la-plaza " || exit 1
PODSUSO=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.status.used.pods}' 2>/dev/null)
echo "$PODSUSO" | grep -qE '^[0-9]+$' || exit 1
test "$PODSUSO" -ge 2 || exit 1
MEMUSO=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.status.used.requests\.memory}' 2>/dev/null)
test -n "$MEMUSO" || exit 1
MEMPUESTO=$(kubectl --kubeconfig "$KC" -n plaza get pod puesto-de-frutas -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null)
test -n "$MEMPUESTO" || exit 1
grep -qxF "CUPO_DE_MEMORIA_PEDIDA=1Gi" "$D/01-respuesta.txt" || exit 1
grep -qxF "MEMORIA_PEDIDA_POR_EL_PUESTO=$MEMPUESTO" "$D/01-respuesta.txt" || exit 1
echo ok
