#!/usr/bin/env bash
# lab-part-04 step 3 - grader
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

# The grader reports through its own explicit `exit 1` lines (and prints ok at the end).
set +e
KC="$HOME/ckad-lab/p04/kubeconfig"
D="$HOME/ckad-lab/p04"
P="kubectl --kubeconfig $KC -n plaza"
test -f "$D/03-respuesta.txt" || exit 1
LISTO=$($P get pod uniformado -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
test "$LISTO" = "True" || exit 1
NOROOT=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
test -n "$NOROOT" || NOROOT=$($P get pod uniformado -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null)
test "$NOROOT" = "true" || exit 1
UIDD=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.runAsUser}' 2>/dev/null)
test -n "$UIDD" || UIDD=$($P get pod uniformado -o jsonpath='{.spec.securityContext.runAsUser}' 2>/dev/null)
echo "$UIDD" | grep -qE '^[0-9]+$' || exit 1
test "$UIDD" -ne 0 || exit 1
SOLOLECTURA=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
test "$SOLOLECTURA" = "true" || exit 1
ESCALAR=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
test "$ESCALAR" = "false" || exit 1
PRIV=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.privileged}' 2>/dev/null)
test "$PRIV" != "true" || exit 1
SUELTAS=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[*]}' 2>/dev/null)
echo "$SUELTAS" | tr ' ' '\n' | grep -qx ALL || exit 1
ANADIDAS=$($P get pod uniformado -o jsonpath='{.spec.containers[0].securityContext.capabilities.add[*]}' 2>/dev/null)
test -z "$ANADIDAS" || exit 1
HOSTS=$($P get pod uniformado -o jsonpath='{.spec.hostNetwork}{.spec.hostPID}{.spec.hostIPC}' 2>/dev/null)
echo "$HOSTS" | grep -q true && exit 1
UIDV=$($P exec uniformado -- id -u 2>/dev/null | tr -d '\r\n')
echo "$UIDV" | grep -qE '^[0-9]+$' || exit 1
test "$UIDV" -ne 0 || exit 1
test "$UIDV" = "$UIDD" || exit 1
CAPEFF=$($P exec uniformado -- sh -c 'grep "^CapEff" /proc/self/status' 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
test "$CAPEFF" = "0000000000000000" || exit 1
CAPBND=$($P exec uniformado -- sh -c 'grep "^CapBnd" /proc/self/status' 2>/dev/null | awk '{print $2}' | tr -d '\r\n')
test "$CAPBND" = "0000000000000000" || exit 1
if $P exec uniformado -- sh -c 'echo sonda > /tmp/sonda-de-calificacion.txt' >/dev/null 2>&1; then exit 1; fi
if $P exec uniformado -- sh -c 'echo sonda > /sonda-de-calificacion.txt' >/dev/null 2>&1; then exit 1; fi
if $P exec uniformado -- sh -c 'echo sonda > /etc/sonda-de-calificacion.txt' >/dev/null 2>&1; then exit 1; fi
PULSO=$($P exec uniformado -- cat /var/latidos/pulso.txt 2>/dev/null | tr -d '\r\n')
echo "$PULSO" | grep -qE '^[0-9]+$' || exit 1
AHORA=$(date -u +%s)
test $((AHORA - PULSO)) -lt 120 || exit 1
test $((AHORA - PULSO)) -ge 0 || exit 1
DURO=$(kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza -o jsonpath='{.spec.hard.requests\.cpu}|{.spec.hard.requests\.memory}|{.spec.hard.limits\.cpu}|{.spec.hard.limits\.memory}|{.spec.hard.pods}' 2>/dev/null)
test "$DURO" = "1|1Gi|2|2Gi|8" || exit 1
grep -qxF "UID_DEL_PROCESO=$UIDV" "$D/03-respuesta.txt" || exit 1
grep -qxF "CAPEFF=$CAPEFF" "$D/03-respuesta.txt" || exit 1
grep -qxF "RAIZ_ESCRIBIBLE=no" "$D/03-respuesta.txt" || exit 1
echo ok
