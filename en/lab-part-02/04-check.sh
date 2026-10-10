#!/usr/bin/env bash
# lab-part-02 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
H="helm --kubeconfig $D/kubeconfig"
NS=la-franquicia
REL=franquicia-del-barrio
DEP=franquicia-del-barrio-podinfo
MENSAJE="lo que pasa es que aqui si atienden"
SONDA="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
test -f "$D/04-respuesta.txt" || exit 1
command -v helm >/dev/null 2>&1 || exit 1
LISTA=$($H list -n $NS --filter "^${REL}\$" -o json 2>/dev/null)
echo "$LISTA" | grep -q "\"name\":\"$REL\"" || exit 1
echo "$LISTA" | grep -q '"status":"deployed"' || exit 1
VCHART=$(echo "$LISTA" | sed -n 's/.*"chart":"podinfo-\([^"]*\)".*/\1/p')
test "$VCHART" = "6.13.0" || exit 1
grep -qxF "VERSION_DEL_CHART=$VCHART" "$D/04-respuesta.txt" || exit 1
SECRETO=$($K -n $NS get secret -l owner=helm,name=$REL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
echo "$SECRETO" | grep -q "^sh\.helm\.release\.v1\.${REL}\." || exit 1
VALORES=$($H get values $REL -n $NS -o json 2>/dev/null)
echo "$VALORES" | grep -q '"replicaCount":3' || exit 1
echo "$VALORES" | grep -qF "\"message\":\"$MENSAJE\"" || exit 1
IMG=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
test "$IMG" = "ghcr.io/stefanprodan/podinfo:$VCHART" || exit 1
DESEADAS=$($K -n $NS get deployment $DEP -o jsonpath='{.spec.replicas}' 2>/dev/null)
LISTAS=$($K -n $NS get deployment $DEP -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
test -n "$LISTAS" || exit 1
test "$LISTAS" = "$DESEADAS" || exit 1
test "$LISTAS" = "3" || exit 1
grep -qxF "REPLICAS_LISTAS=$LISTAS" "$D/04-respuesta.txt" || exit 1
$K -n $NS delete pod sonda-de-la-franquicia --ignore-not-found >/dev/null 2>&1
$K -n $NS run sonda-de-la-franquicia --image="$SONDA" --restart=Never --command -- sleep 600 >/dev/null 2>&1 || exit 1
$K -n $NS wait --for=condition=Ready pod/sonda-de-la-franquicia --timeout=300s >/dev/null 2>&1 || exit 1
CUERPO=""
for _ in $(seq 1 20); do
  CUERPO=$($K -n $NS exec sonda-de-la-franquicia -- wget -qO- "http://${DEP}:9898/" 2>/dev/null)
  test -n "$CUERPO" && break
  sleep 3
done
$K -n $NS delete pod sonda-de-la-franquicia --ignore-not-found --wait=false >/dev/null 2>&1
test -n "$CUERPO" || exit 1
echo "$CUERPO" | grep -q "\"version\": *\"$VCHART\"" || exit 1
echo "$CUERPO" | grep -qF "\"message\": \"$MENSAJE\"" || exit 1
MENSAJE_VIVO=$(echo "$CUERPO" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p')
test -n "$MENSAJE_VIVO" || exit 1
grep -qxF "MENSAJE_VIVO=$MENSAJE_VIVO" "$D/04-respuesta.txt" || exit 1
echo ok
