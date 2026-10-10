#!/usr/bin/env bash
# lab-part-02 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=el-restaurante
DEP=turno-de-almuerzo
MEDIA="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
NUEVA="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"
en_pods() {
  case "$1" in
    *%) P=${1%\%}
        if [ "$3" = "arriba" ]; then echo $(( (P * $2 + 99) / 100 )); else echo $(( P * $2 / 100 )); fi ;;
    *)  echo "$1" ;;
  esac
}
test -f "$D/01-respuesta.txt" || exit 1
TIPO=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.strategy.type}' 2>/dev/null)
test "$TIPO" = "RollingUpdate" || exit 1
REPLICAS=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.replicas}' 2>/dev/null)
test "$REPLICAS" = "4" || exit 1
SURGE=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null)
NODISP=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null)
test -n "$SURGE" || exit 1
test -n "$NODISP" || exit 1
grep -qxF "MAX_SURGE=$SURGE" "$D/01-respuesta.txt" || exit 1
grep -qxF "MAX_UNAVAILABLE=$NODISP" "$D/01-respuesta.txt" || exit 1
test "$(en_pods "$SURGE" "$REPLICAS" arriba)" = "1" || exit 1
test "$(en_pods "$NODISP" "$REPLICAS" abajo)" = "0" || exit 1
LISTAS=$($K -n $NS get deployment $DEP -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
ACTUALIZADAS=$($K -n $NS get deployment $DEP -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
DISPONIBLES=$($K -n $NS get deployment $DEP -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
test "$LISTAS" = "4" || exit 1
test "$ACTUALIZADAS" = "4" || exit 1
test "$DISPONIBLES" = "4" || exit 1
grep -qxF "REPLICAS_LISTAS=$LISTAS" "$D/01-respuesta.txt" || exit 1
IMG=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMG" = "$NUEVA" || exit 1
REV=$($K -n $NS get deployment $DEP -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)
test -n "$REV" || exit 1
test "$REV" -ge 2 || exit 1
IDDEP=$($K -n $NS get deployment $DEP -o jsonpath='{.metadata.uid}' 2>/dev/null)
test -n "$IDDEP" || exit 1
FILAS=$($K -n $NS get rs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].uid}{"|"}{.spec.template.spec.containers[0].image}{"|"}{.spec.replicas}{"\n"}{end}' 2>/dev/null | grep "^$IDDEP|" | cut -d'|' -f2-)
test "$(echo "$FILAS" | grep -c '|')" = "2" || exit 1
echo "$FILAS" | grep -qxF "$MEDIA|0" || exit 1
echo "$FILAS" | grep -qxF "$NUEVA|4" || exit 1
echo ok
