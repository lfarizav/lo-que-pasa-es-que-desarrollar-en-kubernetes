#!/usr/bin/env bash
# lab-part-01 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p01
KC="$HOME/ckad-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-ckad-p01"
BUSYBOX=busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K api-resources --api-group=batch
$K explain job.spec.completions
$K explain job.spec.backoffLimit

cat > los-encargos.yaml <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: los-encargos-del-almuerzo
  namespace: los-encargos
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: el-domiciliario
        image: $BUSYBOX
        command: ["sh","-c","echo encargo entregado por \$(hostname); sleep 2"]
YAML

$K apply -f los-encargos.yaml
$K -n los-encargos wait --for=condition=Complete job/los-encargos-del-almuerzo --timeout=300s

$K -n los-encargos get job los-encargos-del-almuerzo \
  -o jsonpath='{.spec.completions}{" completions, backoffLimit "}{.spec.backoffLimit}{", exitosos "}{.status.succeeded}{"\n"}'
$K -n los-encargos get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{" dueno="}{.metadata.ownerReferences[0].kind}{" fase="}{.status.phase}{"\n"}{end}'
$K -n los-encargos get deployments,replicasets,statefulsets,daemonsets

# The answer file the lab asks you to type, written from the live cluster:
D="$HOME/ckad-lab/p01"
cat > "$D/02-respuesta.txt" <<EOF
DUENO_DE_LOS_PODS=$($K -n los-encargos get pods -o json | jq -r '[.items[].metadata.ownerReferences[0].kind // "ninguno"] | unique | join(" ")')
ENCARGOS_COMPLETADOS=$($K -n los-encargos get job los-encargos-del-almuerzo -o jsonpath='{.status.succeeded}')
REINTENTOS_PERMITIDOS=$($K -n los-encargos get job los-encargos-del-almuerzo -o jsonpath='{.spec.backoffLimit}')
EOF
cat "$D/02-respuesta.txt"
