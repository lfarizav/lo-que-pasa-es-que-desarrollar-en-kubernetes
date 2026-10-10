#!/usr/bin/env bash
# lab-part-04 step 2 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/ckad-lab/p04/kubeconfig"
D="$HOME/ckad-lab/p04"
test -f "$D/02-respuesta.txt" || exit 1
LISTO=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
test "$LISTO" = "True" || exit 1
PLATO=$(kubectl --kubeconfig "$KC" -n plaza get configmap menu-del-dia -o jsonpath="{.data['plato-del-dia']}" 2>/dev/null)
test "$PLATO" = "ajiaco-santafereno" || exit 1
POSTRE=$(kubectl --kubeconfig "$KC" -n plaza get configmap menu-del-dia -o jsonpath="{.data['postre-del-dia']}" 2>/dev/null)
test "$POSTRE" = "brevas-con-arequipe" || exit 1
CLAVE=$(kubectl --kubeconfig "$KC" -n plaza get secret caja-fuerte -o jsonpath='{.data.clave}' 2>/dev/null | base64 -d)
test -n "$CLAVE" || exit 1
TIPO=$(kubectl --kubeconfig "$KC" -n plaza get secret caja-fuerte -o jsonpath='{.type}' 2>/dev/null)
test "$TIPO" = "Opaque" || exit 1
REFS=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].env[?(@.name=="CLAVE_DE_LA_CAJA")].valueFrom.secretKeyRef.name}/{.spec.containers[0].env[?(@.name=="CLAVE_DE_LA_CAJA")].valueFrom.secretKeyRef.key}' 2>/dev/null)
test "$REFS" = "caja-fuerte/clave" || exit 1
LIT=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].env[?(@.name=="CLAVE_DE_LA_CAJA")].value}' 2>/dev/null)
test -z "$LIT" || exit 1
REFM=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].env[?(@.name=="PLATO_DEL_DIA")].valueFrom.configMapKeyRef.name}/{.spec.containers[0].env[?(@.name=="PLATO_DEL_DIA")].valueFrom.configMapKeyRef.key}' 2>/dev/null)
test "$REFM" = "menu-del-dia/plato-del-dia" || exit 1
CRUDO=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[*].env[*].value} {.spec.containers[*].command} {.spec.containers[*].args} {.metadata.annotations}' 2>/dev/null)
echo "$CRUDO" | grep -qF "$CLAVE" && exit 1
VMENU=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/menu")].name}' 2>/dev/null)
test -n "$VMENU" || exit 1
ORIGENM=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath="{.spec.volumes[?(@.name=='$VMENU')].configMap.name}" 2>/dev/null)
test "$ORIGENM" = "menu-del-dia" || exit 1
VCAJA=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].volumeMounts[?(@.mountPath=="/etc/caja")].name}' 2>/dev/null)
test -n "$VCAJA" || exit 1
ORIGENC=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath="{.spec.volumes[?(@.name=='$VCAJA')].secret.secretName}" 2>/dev/null)
test "$ORIGENC" = "caja-fuerte" || exit 1
VACIOS=$(kubectl --kubeconfig "$KC" -n plaza get pod cocinero -o jsonpath='{.spec.volumes[*].emptyDir}{.spec.volumes[*].hostPath}' 2>/dev/null)
test -z "$VACIOS" || exit 1
MPLATO=$(kubectl --kubeconfig "$KC" -n plaza exec cocinero -- cat /etc/menu/plato-del-dia 2>/dev/null | tr -d '\r\n')
test "$MPLATO" = "$PLATO" || exit 1
MPOSTRE=$(kubectl --kubeconfig "$KC" -n plaza exec cocinero -- cat /etc/menu/postre-del-dia 2>/dev/null | tr -d '\r\n')
test "$MPOSTRE" = "$POSTRE" || exit 1
MCLAVE=$(kubectl --kubeconfig "$KC" -n plaza exec cocinero -- cat /etc/caja/clave 2>/dev/null | tr -d '\r\n')
test "$MCLAVE" = "$CLAVE" || exit 1
EPLATO=$(kubectl --kubeconfig "$KC" -n plaza exec cocinero -- printenv PLATO_DEL_DIA 2>/dev/null | tr -d '\r\n')
test "$EPLATO" = "$PLATO" || exit 1
ECLAVE=$(kubectl --kubeconfig "$KC" -n plaza exec cocinero -- printenv CLAVE_DE_LA_CAJA 2>/dev/null | tr -d '\r\n')
test "$ECLAVE" = "$CLAVE" || exit 1
DURO=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard.requests\.cpu}|{.spec.hard.requests\.memory}|{.spec.hard.limits\.cpu}|{.spec.hard.limits\.memory}|{.spec.hard.pods}' 2>/dev/null)
test "$DURO" = "1|1Gi|2|2Gi|8" || exit 1
LARGO=${#CLAVE}
grep -qxF "PLATO_MONTADO=$MPLATO" "$D/02-respuesta.txt" || exit 1
grep -qxF "CLAVE_LARGO=$LARGO" "$D/02-respuesta.txt" || exit 1
grep -qxF "ORIGEN_DE_LA_CLAVE=secretKeyRef" "$D/02-respuesta.txt" || exit 1
echo ok
