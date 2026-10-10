#!/usr/bin/env bash
# lab-part-02 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p02"
K="kubectl --kubeconfig $D/kubeconfig"
NS=la-plaza
SVC=el-restaurante
MEDIA="nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236"
NUEVA="nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de"
test -f "$D/03-respuesta.txt" || exit 1
APP=$($K -n $NS get svc $SVC -o jsonpath='{.spec.selector.app}' 2>/dev/null)
test "$APP" = "menu" || exit 1
VERSEL=$($K -n $NS get svc $SVC -o jsonpath='{.spec.selector.version}' 2>/dev/null)
test -z "$VERSEL" || exit 1
DESPLIEGUES=$($K -n $NS get deployment -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.template.metadata.labels.app}{"|"}{.spec.template.metadata.labels.version}{"|"}{.spec.template.spec.containers[0].image}{"|"}{.status.readyReplicas}{"\n"}{end}' 2>/dev/null | grep '|menu|')
test "$(echo "$DESPLIEGUES" | grep -c '|')" = "2" || exit 1
echo "$DESPLIEGUES" | grep -qE "\|menu\|siempre\|$MEDIA\|8$" || exit 1
echo "$DESPLIEGUES" | grep -qE "\|menu\|nuevo\|$NUEVA\|2$" || exit 1
TOTAL=0; NUEVOS=0; SIEMPRES=0
for _ in $(seq 1 20); do
  MAPA=$($K -n $NS get pods -l app=menu -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.metadata.labels.version}{"\n"}{end}' 2>/dev/null)
  DESTINOS=$($K -n $NS get endpointslices -l kubernetes.io/service-name=$SVC -o jsonpath='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.targetRef.name}{"\n"}{end}{end}' 2>/dev/null)
  TOTAL=0; NUEVOS=0; SIEMPRES=0
  for P in $DESTINOS; do
    V=$(echo "$MAPA" | grep -m1 "^$P|" | cut -d'|' -f2)
    TOTAL=$(( TOTAL + 1 ))
    case "$V" in
      nuevo)   NUEVOS=$(( NUEVOS + 1 )) ;;
      siempre) SIEMPRES=$(( SIEMPRES + 1 )) ;;
    esac
  done
  test "$TOTAL" -eq 10 && break
  sleep 3
done
test "$TOTAL" -eq 10 || exit 1
test "$NUEVOS" -eq 2 || exit 1
test "$SIEMPRES" -eq 8 || exit 1
PORCENTAJE=$(( NUEVOS * 100 / TOTAL ))
grep -qxF "ENDPOINTS_TOTALES=$TOTAL" "$D/03-respuesta.txt" || exit 1
grep -qxF "ENDPOINTS_NUEVO=$NUEVOS" "$D/03-respuesta.txt" || exit 1
grep -qxF "PORCENTAJE_NUEVO=$PORCENTAJE" "$D/03-respuesta.txt" || exit 1
$K -n $NS delete pod sonda-de-trafico --ignore-not-found >/dev/null 2>&1
$K -n $NS run sonda-de-trafico --image="$MEDIA" --restart=Never --command -- sleep 600 >/dev/null 2>&1 || exit 1
$K -n $NS wait --for=condition=Ready pod/sonda-de-trafico --timeout=300s >/dev/null 2>&1 || exit 1
FIRMAS=$($K -n $NS exec sonda-de-trafico -- sh -c 'i=0; while [ $i -lt 100 ]; do wget -qS -O /dev/null http://el-restaurante/ 2>&1 | sed -n "s/.*Server: *//p"; i=$((i+1)); done' 2>/dev/null | sort -u | grep -c .)
$K -n $NS delete pod sonda-de-trafico --ignore-not-found --wait=false >/dev/null 2>&1
if [ "$FIRMAS" -lt 2 ]; then
  echo "ERROR DE SUSTRATO: 100 peticiones al Service $SVC recibieron respuesta de UNA sola version del plato."
  echo "Un Service unico tiene que repartir entre los dos Deployments; si solo contesta uno, el canario no esta"
  echo "recibiendo trafico y todo lo que sigue seria decoracion. Revise que los dos Deployments compartan la"
  echo "etiqueta app=menu y que el selector del Service NO nombre la version."
  exit 1
fi
echo ok
