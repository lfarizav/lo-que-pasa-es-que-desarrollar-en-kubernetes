#!/usr/bin/env bash
# lab-part-04 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

KC="$HOME/ckad-lab/p04/kubeconfig"
cd ~/ckad-lab/p04

cat > uniformado.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: uniformado
  namespace: plaza
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 3000
  containers:
  - name: uniformado
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh","-c","while true; do date -u +%s > /var/latidos/pulso.txt; sleep 5; done"]
    resources:
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: latidos
      mountPath: /var/latidos
  volumes:
  - name: latidos
    emptyDir: {}
YAML

kubectl --kubeconfig "$KC" apply -f uniformado.yaml
kubectl --kubeconfig "$KC" -n plaza wait --for=condition=Ready pod/uniformado --timeout=180s

kubectl --kubeconfig "$KC" -n plaza exec uniformado -- id
kubectl --kubeconfig "$KC" -n plaza exec uniformado -- sh -c 'grep -E "^Cap(Eff|Prm|Bnd)" /proc/self/status'
kubectl --kubeconfig "$KC" -n plaza exec uniformado -- sh -c 'echo prueba > /tmp/prueba.txt' ; echo "codigo de salida al escribir en /tmp: $?"
kubectl --kubeconfig "$KC" -n plaza exec uniformado -- sh -c 'cat /var/latidos/pulso.txt; echo; date -u +%s'
# The answer file the lab asks you to type, written from inside the running container:
K="kubectl --kubeconfig $KC"
if $K -n plaza exec uniformado -- sh -c 'echo prueba > /tmp/prueba.txt' 2>/dev/null; then ESCRIBE=si; else ESCRIBE=no; fi
cat > 03-respuesta.txt <<EOF
UID_DEL_PROCESO=$($K -n plaza exec uniformado -- id -u)
CAPEFF=$($K -n plaza exec uniformado -- sh -c 'grep "^CapEff" /proc/self/status' | awk '{print $2}')
RAIZ_ESCRIBIBLE=$ESCRIBE
EOF
cat 03-respuesta.txt
