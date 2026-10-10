#!/usr/bin/env bash
# lab-part-05 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p05"
K="kubectl --kubeconfig $D/kubeconfig"
test -f "$D/03-respuesta.txt" || exit 1
test "$($K -n la-galeria get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.podSelector}' 2>/dev/null)" = "{}" || exit 1
$K -n la-galeria get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null | grep -qw Ingress || exit 1
test -z "$($K -n la-galeria get netpol negar-todo-lo-que-entra -o jsonpath='{.spec.ingress}' 2>/dev/null)" || exit 1
$K -n la-galeria get netpol dejar-entrar-al-mensajero -o jsonpath='{.spec.podSelector.matchLabels.rol}' 2>/dev/null | grep -qx local || exit 1
$K -n la-galeria get netpol dejar-entrar-al-mensajero -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null | grep -qw Ingress || exit 1
$K -n la-galeria get netpol dejar-entrar-al-mensajero -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels.acceso}' 2>/dev/null | grep -qx permitido || exit 1
$K -n la-galeria get netpol dejar-entrar-al-mensajero -o jsonpath='{.spec.ingress[0].ports[0].port}' 2>/dev/null | grep -qx 80 || exit 1
$K -n la-galeria get pod el-local-de-jugos -o jsonpath='{.metadata.labels.rol}' 2>/dev/null | grep -qx local || exit 1
$K -n la-galeria get pod el-mensajero-con-carnet -o jsonpath='{.metadata.labels.acceso}' 2>/dev/null | grep -qx permitido || exit 1
$K -n la-galeria get pod el-vendedor-ambulante -o jsonpath='{.metadata.labels.acceso}' 2>/dev/null | grep -qx negado || exit 1
DESTINO=$($K -n la-galeria get pod el-local-de-jugos -o jsonpath='{.status.podIP}' 2>/dev/null)
test -n "$DESTINO" || exit 1
$K -n la-galeria exec el-mensajero-con-carnet -- wget -q -T 8 -O- "http://$DESTINO" >/dev/null 2>&1 || exit 1
if $K -n la-galeria exec el-vendedor-ambulante -- wget -q -T 8 -O- "http://$DESTINO" >/dev/null 2>&1; then exit 1; fi
grep -qxF "SALIDA_CON_CARNET=0" "$D/03-respuesta.txt" || exit 1
SIN=$(grep -oP '(?<=SALIDA_SIN_CARNET=).*' "$D/03-respuesta.txt")
test -n "$SIN" || exit 1
test "$SIN" != "0" || exit 1
echo ok
