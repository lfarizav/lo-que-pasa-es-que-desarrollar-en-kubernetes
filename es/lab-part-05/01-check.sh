#!/usr/bin/env bash
# lab-part-05 step 1 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p05"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/01-respuesta.txt" || exit 1
test "$($K -n la-plazoleta get deploy cocina-central -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "3" || exit 1
$K -n la-plazoleta get svc domicilios -o jsonpath='{.spec.type}' 2>/dev/null | grep -qx ClusterIP || exit 1
$K -n la-plazoleta get svc domicilios -o jsonpath='{.spec.ports[0].port}' 2>/dev/null | grep -qx 80 || exit 1
SEL=$($K -n la-plazoleta get svc domicilios -o jsonpath='{.spec.selector}' 2>/dev/null)
test -n "$SEL" || exit 1
test "$SEL" != "{}" || exit 1
CIP=$($K -n la-plazoleta get svc domicilios -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
test -n "$CIP" || exit 1
test "$CIP" != "None" || exit 1
IPS_REALES=$($K -n la-plazoleta get pods -l app=cocina-central -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
test "$(echo $IPS_REALES | wc -w)" -eq 3 || exit 1
$K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios -o jsonpath='{.items[0].metadata.labels.endpointslice\.kubernetes\.io/managed-by}' 2>/dev/null | grep -qx 'endpointslice-controller.k8s.io' || exit 1
DIRS=$($K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios -o jsonpath="$JP_LISTOS" 2>/dev/null | sort | tr '\n' ' ')
test "$DIRS" = "$IPS_REALES" || exit 1
$K -n la-plazoleta get pod el-mensajero -o jsonpath='{.status.phase}' 2>/dev/null | grep -qx Running || exit 1
FQDN=$(grep -oP '(?<=NOMBRE_COMPLETO=).*' "$D/01-respuesta.txt")
test "$FQDN" = "domicilios.la-plazoleta.svc.cluster.local" || exit 1
RESUELTA=$($K -n la-plazoleta exec el-mensajero -- nslookup "$FQDN" 2>/dev/null | tr -d '\r' | awk -F'[ \t]+' '/^Address:/{print $2}' | grep -vE '[#:]' | head -1)
test "$RESUELTA" = "$CIP" || exit 1
grep -qxF "CLUSTERIP_POR_DNS=$CIP" "$D/01-respuesta.txt" || exit 1
$K -n la-plazoleta exec el-mensajero -- wget -q -T 8 -O- "http://$FQDN/" >/dev/null 2>&1 || exit 1
N=$(echo $DIRS | wc -w)
grep -qxF "ENDPOINTS_LISTOS=$N" "$D/01-respuesta.txt" || exit 1
echo ok
