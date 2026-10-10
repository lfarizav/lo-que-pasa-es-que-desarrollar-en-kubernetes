#!/usr/bin/env bash
# lab-part-04 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

KC="$HOME/ckad-lab/p04/kubeconfig"
cd ~/ckad-lab/p04

kubectl --kubeconfig "$KC" -n plaza create configmap menu-del-dia \
  --from-literal=plato-del-dia='ajiaco-santafereno' \
  --from-literal=postre-del-dia='brevas-con-arequipe'

kubectl --kubeconfig "$KC" -n plaza get secret caja-fuerte -o jsonpath='tipo={.type}{"\n"}llaves={.data}{"\n"}'

cat > cocinero.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: cocinero
  namespace: plaza
spec:
  containers:
  - name: cocinero
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh","-c","sleep 86400"]
    resources:
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
    env:
    - name: PLATO_DEL_DIA
      valueFrom:
        configMapKeyRef:
          name: menu-del-dia
          key: plato-del-dia
    - name: CLAVE_DE_LA_CAJA
      valueFrom:
        secretKeyRef:
          name: caja-fuerte
          key: clave
    volumeMounts:
    - name: menu
      mountPath: /etc/menu
      readOnly: true
    - name: caja
      mountPath: /etc/caja
      readOnly: true
  volumes:
  - name: menu
    configMap:
      name: menu-del-dia
  - name: caja
    secret:
      secretName: caja-fuerte
YAML

kubectl --kubeconfig "$KC" apply -f cocinero.yaml
kubectl --kubeconfig "$KC" -n plaza wait --for=condition=Ready pod/cocinero --timeout=180s

kubectl --kubeconfig "$KC" -n plaza exec cocinero -- ls -1 /etc/menu /etc/caja
kubectl --kubeconfig "$KC" -n plaza exec cocinero -- cat /etc/menu/plato-del-dia
kubectl --kubeconfig "$KC" -n plaza exec cocinero -- printenv PLATO_DEL_DIA
kubectl --kubeconfig "$KC" -n plaza exec cocinero -- sh -c 'wc -c < /etc/caja/clave'
# The answer file the lab asks you to type, written from inside the running container:
K="kubectl --kubeconfig $KC"
cat > 02-respuesta.txt <<EOF
PLATO_MONTADO=$($K -n plaza exec cocinero -- cat /etc/menu/plato-del-dia)
CLAVE_LARGO=$($K -n plaza exec cocinero -- sh -c 'wc -c < /etc/caja/clave' | tr -d ' \r')
ORIGEN_DE_LA_CLAVE=$($K -n plaza get pod cocinero -o jsonpath='{.spec.containers[0].env[?(@.name=="CLAVE_DE_LA_CAJA")].valueFrom}' | sed -n 's/^{"\([a-zA-Z]*\)".*/\1/p')
EOF
cat 02-respuesta.txt
