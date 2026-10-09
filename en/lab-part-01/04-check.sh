#!/usr/bin/env bash
# lab-part-01 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-ckad-p01"
NS=la-nevera
POD=el-almuerzo-del-dia
DIGESTO=sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
test -f "$D/04-respuesta.txt" || exit 1
P=$($K -n $NS get pod $POD -o json 2>/dev/null)
test -n "$P" || exit 1
test "$(echo "$P" | jq -r '.status.phase')" = "Running" || exit 1
echo "$P" | jq -e '[.status.conditions[]? | select(.type == "Ready" and .status == "True")] | length == 1' >/dev/null || exit 1
test "$(echo "$P" | jq '.spec.initContainers // [] | length')" -ge 1 || exit 1
ESTADO=$(echo "$P" | jq -r '.status.initContainerStatuses[0].state.terminated.reason // empty')
test "$ESTADO" = "Completed" || exit 1
test "$(echo "$P" | jq -r '.status.initContainerStatuses[0].state.terminated.exitCode // 1')" = "0" || exit 1
grep -qxF "ESTADO_DEL_AYUDANTE=$ESTADO" "$D/04-respuesta.txt" || exit 1
echo "$P" | jq -e --arg d "$DIGESTO" 'all((.spec.initContainers + .spec.containers)[]; .image | endswith($d))' >/dev/null || exit 1
COMPARTIDO=$(echo "$P" | jq -r '
  ([.spec.volumes[]? | select(has("emptyDir")) | .name]) as $vacios
  | ([.spec.initContainers[]?.volumeMounts[]?.name]) as $ayudante
  | ([.spec.containers[]?.volumeMounts[]?.name]) as $cocinero
  | [$vacios[] | select((($ayudante | index(.)) != null) and (($cocinero | index(.)) != null))]
  | .[0] // empty')
test -n "$COMPARTIDO" || exit 1
TIPO=$(echo "$P" | jq -r --arg n "$COMPARTIDO" '.spec.volumes[] | select(.name == $n) | (keys_unsorted - ["name"])[0]')
test "$TIPO" = "emptyDir" || exit 1
grep -qxF "TIPO_DE_VOLUMEN=$TIPO" "$D/04-respuesta.txt" || exit 1
COCINERO=$(echo "$P" | jq -r --arg n "$COMPARTIDO" '[.spec.containers[] | select(any(.volumeMounts[]?; .name == $n))][0].name')
RUTA=$(echo "$P" | jq -r --arg n "$COMPARTIDO" --arg c "$COCINERO" '.spec.containers[] | select(.name == $c) | .volumeMounts[] | select(.name == $n) | .mountPath')
test -n "$COCINERO" || exit 1
test -n "$RUTA" || exit 1
GUARDADO=$($K -n $NS exec $POD -c "$COCINERO" -- cat "$RUTA/index.html" 2>/dev/null | tr -d '\r' | head -1)
test "$GUARDADO" = "el-ayudante-dejo-listo-el-mise-en-place" || exit 1
SERVIDO=$($K -n $NS exec $POD -c "$COCINERO" -- wget -qO- 127.0.0.1:8080/index.html 2>/dev/null | tr -d '\r' | head -1)
test "$SERVIDO" = "$GUARDADO" || exit 1
grep -qxF "LO_QUE_SIRVE_LA_COCINA=$SERVIDO" "$D/04-respuesta.txt" || exit 1
echo ok
