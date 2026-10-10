#!/usr/bin/env bash
# lab-part-05 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
D="$HOME/ckad-lab/p05"
K="kubectl --kubeconfig $D/kubeconfig"
JP_LISTOS='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}'
test -f "$D/02-respuesta.txt" || exit 1
test "$($K -n la-plazoleta get deploy heladeria-la-nieve -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "2" || exit 1
$K -n la-plazoleta get svc domicilios-heladeria -o jsonpath='{.spec.selector.app}' 2>/dev/null | grep -qx heladeria-la-nieve || exit 1
$K -n la-plazoleta get deploy heladeria-la-nieve -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null | grep -qx heladeria-la-nieve || exit 1
SEDE_SVC=$($K -n la-plazoleta get svc domicilios-heladeria -o jsonpath='{.spec.selector.sede}' 2>/dev/null)
SEDE_DEP=$($K -n la-plazoleta get deploy heladeria-la-nieve -o jsonpath='{.spec.template.metadata.labels.sede}' 2>/dev/null)
test -n "$SEDE_SVC" || exit 1
test -n "$SEDE_DEP" || exit 1
test "$SEDE_SVC" = "$SEDE_DEP" || exit 1
IPS_REALES=$($K -n la-plazoleta get pods -l "app=heladeria-la-nieve,sede=$SEDE_DEP" -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort | tr '\n' ' ')
test "$(echo $IPS_REALES | wc -w)" -eq 2 || exit 1
$K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios-heladeria -o jsonpath='{.items[0].metadata.labels.endpointslice\.kubernetes\.io/managed-by}' 2>/dev/null | grep -qx 'endpointslice-controller.k8s.io' || exit 1
DIRS=$($K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios-heladeria -o jsonpath="$JP_LISTOS" 2>/dev/null | sort | tr '\n' ' ')
test "$DIRS" = "$IPS_REALES" || exit 1
grep -qxF "SEDE_ACORDADA=$SEDE_SVC" "$D/02-respuesta.txt" || exit 1
LADO=$(grep -oP '(?<=LADO_QUE_CAMBIE=).*' "$D/02-respuesta.txt")
case "$LADO" in
  servicio)   test "$SEDE_SVC" = "norte" || exit 1 ;;
  deployment) test "$SEDE_SVC" = "sur"   || exit 1 ;;
  ambos)      test "$SEDE_SVC" != "norte" && test "$SEDE_SVC" != "sur" || exit 1 ;;
  *) exit 1 ;;
esac
N=$(echo $DIRS | wc -w)
grep -qxF "ENDPOINTS_HELADERIA=$N" "$D/02-respuesta.txt" || exit 1
echo ok
