#!/usr/bin/env bash
# lab-part-02 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=el-restaurante
DEP=carta-de-la-semana
VIEJA="nginx:1.27-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10"
MEDIA="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
NUEVA="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"
test -f "$D/02-respuesta.txt" || exit 1
REV=$($K -n $NS get deployment $DEP -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null)
test -n "$REV" || exit 1
test "$REV" -ge 4 || exit 1
grep -qxF "REVISION_FINAL=$REV" "$D/02-respuesta.txt" || exit 1
IMG=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMG" = "$MEDIA" || exit 1
grep -qxF "IMAGEN_VIVA=$IMG" "$D/02-respuesta.txt" || exit 1
DESEADAS=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deployment $DEP -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test -n "$LISTAS" || exit 1
test "$LISTAS" = "$DESEADAS" || exit 1
test "$LISTAS" -ge 3 || exit 1
IDDEP=$($K -n $NS get deployment $DEP -o jsonpath='{.metadata.uid}' 2>/dev/null)
test -n "$IDDEP" || exit 1
FILAS=$($K -n $NS get rs -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].uid}{"|"}{.metadata.annotations.deployment\.kubernetes\.io/revision}{"|"}{.spec.template.spec.containers[0].image}{"|"}{.spec.replicas}{"\n"}{end}' 2>/dev/null | grep "^$IDDEP|" | cut -d'|' -f2-)
test "$(echo "$FILAS" | grep -c '|')" = "3" || exit 1
echo "$FILAS" | grep -qxF "1|$VIEJA|0" || exit 1
echo "$FILAS" | grep -qxF "$REV|$MEDIA|$DESEADAS" || exit 1
echo "$FILAS" | grep -qE "^[0-9]+\|$NUEVA\|0$" || exit 1
REVS=$(echo "$FILAS" | cut -d'|' -f1 | sort -n | paste -sd, -)
grep -qxF "REVISIONES_VIVAS=$REVS" "$D/02-respuesta.txt" || exit 1
echo "$FILAS" | cut -d'|' -f1 | grep -qx 2 && exit 1
echo ok
