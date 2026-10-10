#!/usr/bin/env bash
# lab-part-03 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. Que paso cuando el clúster vio el manifiesto. El montaje ya lo intento y
#    guardo el rechazo textual.
cat "$W/inventario/apply-fallido.log"
$K -n el-deposito get cronjobs

# 2. El manifiesto que le entregaron, y la version de API contra la que fue escrito.
head -3 "$W/inventario/conteo-inventario.yaml"

# 3. El catalogo vigente de este clúster: que version sirve HOY para este recurso.
$K api-resources --api-group=batch
$K explain cronjob --recursive | head -5

# 4. Recetar: solo cambia la pagina del catalogo, nunca lo que el objeto hace.
#    El nombre, el horario y el comando se quedan iguales.
sed -i 's|^apiVersion: batch/v1beta1$|apiVersion: batch/v1|' "$W/inventario/conteo-inventario.yaml"
$K apply -f "$W/inventario/conteo-inventario.yaml"

# 5. Esperar a que el horario dispare el primer Job y confirmar que termino bien.
for i in $(seq 1 30); do
  N=$($K -n el-deposito get jobs -o jsonpath='{range .items[*]}{.status.succeeded}{"\n"}{end}' 2>/dev/null | grep -c '^1$' || true)
  [ "${N:-0}" -ge 1 ] && break
  sleep 5
done
$K -n el-deposito get cronjob,jobs
JOB=$($K -n el-deposito get jobs -o jsonpath='{.items[0].metadata.name}')
$K -n el-deposito logs -l job-name="$JOB"

# The answer file the lab asks you to type, written from the saved rejection and the live
# cluster. The retirement version is not stored in the cluster: it comes from the official
# deprecation guide, https://kubernetes.io/docs/reference/using-api/deprecation-guide/
# ("The batch/v1beta1 API version of CronJob is no longer served as of v1.25").
cat > "$W/04-respuesta.txt" <<EOF
APIVERSION_MUERTA=$(sed -n 's/.*in version "\([^"]*\)".*/\1/p' "$W/inventario/apply-fallido.log" | head -1)
APIVERSION_VIVA=$($K -n el-deposito get cronjob conteo-inventario -o jsonpath='{.apiVersion}')
VERSION_QUE_LA_RETIRO=v1.25
EOF
cat "$W/04-respuesta.txt"
