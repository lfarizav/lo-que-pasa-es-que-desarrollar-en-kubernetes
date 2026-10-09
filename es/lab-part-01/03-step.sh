#!/usr/bin/env bash
# lab-part-01 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p01
KC="$HOME/ckad-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-ckad-p01"
BUSYBOX=busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K explain cronjob.spec.schedule
$K explain cronjob.spec.successfulJobsHistoryLimit
$K explain cronjob.spec.failedJobsHistoryLimit

cat > el-pan.yaml <<YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: el-pan-de-la-madrugada
  namespace: la-madrugada
spec:
  schedule: "*/1 * * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: el-panadero
            image: $BUSYBOX
            command: ["sh","-c","echo pan horneado a las \$(date -u +%H:%M:%S) UTC; sleep 2"]
YAML

$K apply -f el-pan.yaml
$K -n la-madrugada get cronjob el-pan-de-la-madrugada

echo "esperando la primera horneada, hasta 120 s"
for INTENTO in $(seq 1 24); do
  HORA=$($K -n la-madrugada get cronjob el-pan-de-la-madrugada -o jsonpath='{.status.lastScheduleTime}')
  test -n "$HORA" && break
  sleep 5
done

echo "esperando que esa horneada termine con exito, hasta 120 s"
for INTENTO in $(seq 1 24); do
  LISTOS=$($K -n la-madrugada get jobs -o jsonpath='{range .items[*]}{.status.succeeded}{"\n"}{end}' | grep -c '^[1-9]')
  test "$LISTOS" -ge 1 && break
  sleep 5
done

$K -n la-madrugada get cronjob el-pan-de-la-madrugada \
  -o jsonpath='{.spec.schedule}{" | exitosos "}{.spec.successfulJobsHistoryLimit}{" | fallidos "}{.spec.failedJobsHistoryLimit}{" | ultima "}{.status.lastScheduleTime}{"\n"}'
$K -n la-madrugada get jobs \
  -o jsonpath='{range .items[*]}{.metadata.name}{" dueno="}{.metadata.ownerReferences[0].kind}{" exitosos="}{.status.succeeded}{"\n"}{end}'
$K -n la-madrugada logs -l batch.kubernetes.io/job-name --tail=5 --prefix

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p01"
cat > "$D/03-respuesta.txt" <<EOF
HORARIO_DEL_PAN=$($K -n la-madrugada get cronjob el-pan-de-la-madrugada -o jsonpath='{.spec.schedule}')
HISTORIAL_DE_EXITOSOS=$($K -n la-madrugada get cronjob el-pan-de-la-madrugada -o jsonpath='{.spec.successfulJobsHistoryLimit}')
DUENO_DE_LOS_EMPLEOS=$($K -n la-madrugada get jobs -o json | jq -r '[.items[] | select(.metadata.ownerReferences)][0].metadata.ownerReferences[0].kind')
EOF
cat "$D/03-respuesta.txt"
