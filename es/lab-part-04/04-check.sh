#!/usr/bin/env bash
# lab-part-04 step 4 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/ckad-lab/p04/kubeconfig"
D="$HOME/ckad-lab/p04"
K="kubectl --kubeconfig $KC"
SA="system:serviceaccount:plaza:carnet-del-mesero"
test -f "$D/04-respuesta.txt" || exit 1
$K -n plaza get serviceaccount carnet-del-mesero >/dev/null 2>&1 || exit 1
for V in get list; do
  R=$($K auth can-i $V configmaps -n plaza --as="$SA" 2>/dev/null)
  test "$R" = "yes" || exit 1
done
for V in get list; do
  R=$($K auth can-i $V pedidos.plaza.example.com -n plaza --as="$SA" 2>/dev/null)
  test "$R" = "yes" || exit 1
done
for V in delete create update patch deletecollection; do
  R=$($K auth can-i $V configmaps -n plaza --as="$SA" 2>/dev/null)
  test "$R" = "no" || exit 1
  R=$($K auth can-i $V pedidos.plaza.example.com -n plaza --as="$SA" 2>/dev/null)
  test "$R" = "no" || exit 1
done
for V in get list watch; do
  R=$($K auth can-i $V secrets -n plaza --as="$SA" 2>/dev/null)
  test "$R" = "no" || exit 1
done
R=$($K auth can-i create pods -n plaza --as="$SA" 2>/dev/null)
test "$R" = "no" || exit 1
R=$($K auth can-i get configmaps -n kube-system --as="$SA" 2>/dev/null)
test "$R" = "no" || exit 1
R=$($K auth can-i '*' '*' --all-namespaces --as="$SA" 2>/dev/null)
test "$R" = "no" || exit 1
CRB=$($K get clusterrolebindings -o jsonpath='{range .items[*]}{range .subjects[*]}{.kind}/{.namespace}/{.name}{"\n"}{end}{end}' 2>/dev/null)
echo "$CRB" | grep -qx 'ServiceAccount/plaza/carnet-del-mesero' && exit 1
LISTO=$($K -n plaza get pod mesero -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
test "$LISTO" = "True" || exit 1
CUENTA=$($K -n plaza get pod mesero -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
test "$CUENTA" = "carnet-del-mesero" || exit 1
AUTO=$($K -n plaza get pod mesero -o jsonpath='{.spec.automountServiceAccountToken}' 2>/dev/null)
test "$AUTO" != "false" || exit 1
NSARCH=$($K -n plaza exec mesero -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null | tr -d '\r\n')
test "$NSARCH" = "plaza" || exit 1
LEE=$($K -n plaza exec mesero -- sh -c '
T=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
wget -q -S -O /dev/null --no-check-certificate --header="Authorization: Bearer $T" "https://kubernetes.default.svc/api/v1/namespaces/$NS/configmaps/menu-del-dia" 2>&1 | grep -m1 -oE "HTTP/1.1 [0-9]+"' 2>/dev/null | tr -d '\r\n')
test "$LEE" = "HTTP/1.1 200" || exit 1
PED=$($K -n plaza exec mesero -- sh -c '
T=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
wget -q -S -O /dev/null --no-check-certificate --header="Authorization: Bearer $T" "https://kubernetes.default.svc/apis/plaza.example.com/v1/namespaces/$NS/pedidos" 2>&1 | grep -m1 -oE "HTTP/1.1 [0-9]+"' 2>/dev/null | tr -d '\r\n')
test "$PED" = "HTTP/1.1 200" || exit 1
CAJA=$($K -n plaza exec mesero -- sh -c '
T=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
wget -q -S -O /dev/null --no-check-certificate --header="Authorization: Bearer $T" "https://kubernetes.default.svc/api/v1/namespaces/$NS/secrets/caja-fuerte" 2>&1 | grep -m1 -oE "HTTP/1.1 [0-9]+"' 2>/dev/null | tr -d '\r\n')
test "$CAJA" = "HTTP/1.1 403" || exit 1
CODIGO=${CAJA##* }
DURO=$($K -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard.requests\.cpu}|{.spec.hard.requests\.memory}|{.spec.hard.limits\.cpu}|{.spec.hard.limits\.memory}|{.spec.hard.pods}' 2>/dev/null)
test "$DURO" = "1|1Gi|2|2Gi|8" || exit 1
grep -qxF "CUENTA_DEL_MESERO=$CUENTA" "$D/04-respuesta.txt" || exit 1
grep -qxF "PUEDE_LEER_EL_MENU=yes" "$D/04-respuesta.txt" || exit 1
grep -qxF "PUEDE_BORRAR_EL_MENU=no" "$D/04-respuesta.txt" || exit 1
grep -qxF "PUEDE_LEER_LOS_PEDIDOS=yes" "$D/04-respuesta.txt" || exit 1
grep -qxF "CODIGO_EN_LA_CAJA=$CODIGO" "$D/04-respuesta.txt" || exit 1
echo ok
