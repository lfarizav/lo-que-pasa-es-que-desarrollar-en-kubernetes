#!/usr/bin/env bash
# lab-part-03 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"; R="$W/03-respuesta.txt"
CURL="curlimages/curl@sha256:d94d07ba9e7d6de898b6d96c1a072f6f8266c687af78a74f380087a0addf5d17"
test -f "$R" || exit 1
grep -qxF "MENSAJE_FATAL=FATAL: PAGINA_CATALOGO vacia, el catalogo no abre" "$R" || exit 1
grep -qxF "LLAVE_FANTASMA=PAGINA_VIEJA" "$R" || exit 1
grep -qxF "CAMPO_QUE_LO_TAPO=optional" "$R" || exit 1
test "$($K -n el-catalogo get deploy catalogo -o jsonpath='{.spec.replicas}' 2>/dev/null)" = "1" || exit 1
$K -n el-catalogo rollout status deployment/catalogo --timeout=180s >/dev/null 2>&1 || exit 1
test "$($K -n el-catalogo get deploy catalogo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" || exit 1
CMN=$($K -n el-catalogo get deploy catalogo -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PAGINA_CATALOGO")].valueFrom.configMapKeyRef.name}' 2>/dev/null)
CMK=$($K -n el-catalogo get deploy catalogo -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="PAGINA_CATALOGO")].valueFrom.configMapKeyRef.key}' 2>/dev/null)
test "$CMN" = "el-inventario" || exit 1
test "$CMK" = "PAGINA_CATALOGO" || exit 1
VAL=$($K -n el-catalogo get configmap el-inventario -o jsonpath='{.data.PAGINA_CATALOGO}' 2>/dev/null)
test -n "$VAL" || exit 1
POD=""
for p in $($K -n el-catalogo get pod -l app=catalogo -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null); do
  LISTO=$($K -n el-catalogo get pod "$p" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  MUERE=$($K -n el-catalogo get pod "$p" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)
  if [ "$LISTO" = "True" ] && [ -z "$MUERE" ]; then POD="$p"; break; fi
done
test -n "$POD" || exit 1
VIVO=$($K -n el-catalogo exec "$POD" -- printenv PAGINA_CATALOGO 2>/dev/null | tr -d '\r\n')
test "$VIVO" = "$VAL" || exit 1
$K -n default get pod mandadero >/dev/null 2>&1 || \
  $K -n default run mandadero --image="$CURL" --restart=Never --command -- sleep 86400 >/dev/null 2>&1
$K -n default wait --for=condition=Ready pod/mandadero --timeout=300s >/dev/null 2>&1 || exit 1
OK=no
for i in 1 2 3 4 5 6; do
  CUERPO=$($K -n default exec mandadero -- curl -s --max-time 8 http://catalogo.el-catalogo.svc.cluster.local/ 2>/dev/null)
  if echo "$CUERPO" | grep -qF "$VAL"; then OK=si; break; fi
  sleep 5
done
test "$OK" = "si" || exit 1
echo ok
