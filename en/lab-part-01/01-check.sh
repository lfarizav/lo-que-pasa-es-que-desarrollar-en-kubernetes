#!/usr/bin/env bash
# lab-part-01 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p01"
K="kubectl --kubeconfig $D/kubeconfig --context kind-ckad-p01"
NS=la-cocina
test -f "$D/01-respuesta.txt" || exit 1
DES=$($K -n $NS get deploy el-restaurante -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deploy el-restaurante -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test "$DES" = "2" || exit 1
test "$LISTAS" = "2" || exit 1
grep -qxF "REPLICAS_LISTAS=$LISTAS" "$D/01-respuesta.txt" || exit 1
PLANTILLA=$($K -n $NS get deploy el-restaurante -o json 2>/dev/null | jq -c '.spec.template.spec.containers[0]')
test "$(echo "$PLANTILLA" | jq -r '.image')" = "la-receta:1.0" || exit 1
test "$(echo "$PLANTILLA" | jq -r '.imagePullPolicy // "IfNotPresent"')" != "Always" || exit 1
SELECTOR=$($K -n $NS get deploy el-restaurante -o json 2>/dev/null | jq -r '.spec.selector.matchLabels | to_entries | map("\(.key)=\(.value)") | join(",")')
test -n "$SELECTOR" || exit 1
VIVOS=$($K -n $NS get pods -l "$SELECTOR" -o json 2>/dev/null | jq -c '[.items[] | select(.metadata.deletionTimestamp == null) | select(.status.phase == "Running") | select(any(.status.conditions[]?; .type == "Ready" and .status == "True"))]')
test "$(echo "$VIVOS" | jq 'length')" -eq 2 || exit 1
IMAGENES=$(echo "$VIVOS" | jq -r '[.[].spec.containers[0].image] | unique | join(" ")')
test "$IMAGENES" = "la-receta:1.0" || exit 1
grep -qxF "IMAGEN_DEL_DESPLIEGUE=$IMAGENES" "$D/01-respuesta.txt" || exit 1
echo "$VIVOS" | jq -e 'any(.[].spec.containers[0].imagePullPolicy; . == "Always")' >/dev/null && exit 1
docker image inspect la-receta:1.0 >/dev/null 2>&1 || exit 1
NODO=$($K get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
test -n "$NODO" || exit 1
FICHA=$(docker exec "$NODO" crictl images -o json 2>/dev/null | jq -c '[.images[] | select(any(.repoTags[]?; . == "docker.io/library/la-receta:1.0"))][0] // empty')
test -n "$FICHA" || exit 1
ETIQUETA=$(echo "$FICHA" | jq -r '.repoTags[0]')
grep -qxF "IMAGEN_EN_EL_NODO=$ETIQUETA" "$D/01-respuesta.txt" || exit 1
for HUELLA in $(echo "$VIVOS" | jq -r '[.[].status.containerStatuses[0].imageID] | unique | .[]'); do
  echo "$FICHA" | jq -e --arg h "$HUELLA" '.id == $h or any(.repoDigests[]?; . == $h)' >/dev/null || exit 1
done
POD=$(echo "$VIVOS" | jq -r '.[0].metadata.name')
CARTA=$($K -n $NS exec "$POD" -- wget -qO- 127.0.0.1:8080/index.html 2>/dev/null | tr -d '\r' | head -1)
test "$CARTA" = "la-carta-del-restaurante-v1" || exit 1
grep -qxF "LO_QUE_SIRVE_LA_CARTA=$CARTA" "$D/01-respuesta.txt" || exit 1
echo ok
