#!/usr/bin/env bash
# lab-part-04 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

KC="$HOME/ckad-lab/p04/kubeconfig"
cd ~/ckad-lab/p04

kubectl --kubeconfig "$KC" get crd pedidos.plaza.example.com \
  -o jsonpath='grupo={.spec.group}{"\n"}plural={.spec.names.plural}{"\n"}alcance={.spec.scope}{"\n"}'
kubectl --kubeconfig "$KC" -n plaza get pedidos

kubectl --kubeconfig "$KC" -n plaza create serviceaccount carnet-del-mesero
kubectl --kubeconfig "$KC" -n plaza create role leer-el-menu \
  --verb=get,list --resource=configmaps
kubectl --kubeconfig "$KC" -n plaza patch role leer-el-menu --type=json \
  -p '[{"op":"add","path":"/rules/-","value":{"apiGroups":["plaza.example.com"],"resources":["pedidos"],"verbs":["get","list"]}}]'
kubectl --kubeconfig "$KC" -n plaza create rolebinding el-mesero-lee-el-menu \
  --role=leer-el-menu --serviceaccount=plaza:carnet-del-mesero

cat > mesero.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: mesero
  namespace: plaza
spec:
  serviceAccountName: carnet-del-mesero
  containers:
  - name: mesero
    image: busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
    command: ["sh","-c","sleep 86400"]
    resources:
      requests:
        cpu: 100m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 128Mi
YAML
kubectl --kubeconfig "$KC" apply -f mesero.yaml
kubectl --kubeconfig "$KC" -n plaza wait --for=condition=Ready pod/mesero --timeout=180s

CARNE="system:serviceaccount:plaza:carnet-del-mesero"
for PERMISO in "get configmaps" "list configmaps" "delete configmaps" "get secrets" \
               "get pedidos.plaza.example.com" "delete pedidos.plaza.example.com"; do
  printf '%-38s -> ' "$PERMISO"
  kubectl --kubeconfig "$KC" auth can-i $PERMISO -n plaza --as="$CARNE"
done
printf '%-38s -> ' "todo en todos los namespaces"
kubectl --kubeconfig "$KC" auth can-i '*' '*' --all-namespaces --as="$CARNE"

kubectl --kubeconfig "$KC" -n plaza exec mesero -- sh -c '
T=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
echo "namespace del carne: $NS"
for RUTA in "api/v1/namespaces/$NS/configmaps/menu-del-dia" \
            "apis/plaza.example.com/v1/namespaces/$NS/pedidos" \
            "api/v1/namespaces/$NS/secrets/caja-fuerte"; do
  printf "%-58s -> " "/$RUTA"
  wget -q -S -O /dev/null --no-check-certificate \
    --header="Authorization: Bearer $T" "https://kubernetes.default.svc/$RUTA" 2>&1 \
    | grep -m1 -oE "HTTP/1.1 [0-9]+"
done'
# The answer file the lab asks you to type, written from the live cluster and from inside the Pod:
K="kubectl --kubeconfig $KC"
CARNE="system:serviceaccount:plaza:carnet-del-mesero"
CAJA=$($K -n plaza exec mesero -- sh -c '
T=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
wget -q -S -O /dev/null --no-check-certificate --header="Authorization: Bearer $T" \
  "https://kubernetes.default.svc/api/v1/namespaces/plaza/secrets/caja-fuerte" 2>&1 | grep -m1 -oE "HTTP/1.1 [0-9]+"')
cat > 04-respuesta.txt <<EOF
CUENTA_DEL_MESERO=$($K -n plaza get pod mesero -o jsonpath='{.spec.serviceAccountName}')
PUEDE_LEER_EL_MENU=$($K auth can-i get configmaps -n plaza --as="$CARNE")
PUEDE_BORRAR_EL_MENU=$($K auth can-i delete configmaps -n plaza --as="$CARNE")
PUEDE_LEER_LOS_PEDIDOS=$($K auth can-i get pedidos.plaza.example.com -n plaza --as="$CARNE")
CODIGO_EN_LA_CAJA=${CAJA##* }
EOF
cat 04-respuesta.txt
