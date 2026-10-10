#!/usr/bin/env bash
# lab-part-05 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

mkdir -p ~/ckad-lab/p05
cd ~/ckad-lab/p05

for tool in kind kubectl docker curl base64; do
  command -v "$tool" >/dev/null 2>&1 || echo "FALTA: $tool - instalelo antes de continuar."
done

for p in 8085 8543; do
  ss -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN && echo "OCUPADO: el puerto $p del host esta en uso; cambielo en kind-p05.yaml."
done

cat > kind-p05.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
  image: kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5
  extraPortMappings:
  - containerPort: 80
    hostPort: 8085
    protocol: TCP
  - containerPort: 443
    hostPort: 8543
    protocol: TCP
YAML

kind create cluster --name ckad-p05 \
  --kubeconfig ~/ckad-lab/p05/kubeconfig \
  --config kind-p05.yaml

K="kubectl --kubeconfig $HOME/ckad-lab/p05/kubeconfig"

echo "instalando Calico v3.32.1 (sin el, el Paso 3 no probaria nada)"

# Los CRD van primero y explicitos. El operador tambien los instala solo al
# arrancar, pero unos segundos DESPUES de que su Deployment queda rolled out,
# asi que aplicar el recurso Installation enseguida falla con
# "no matches for kind Installation" y el resto se cae en cascada.
$K apply --server-side \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/operator-crds.yaml
$K wait --for=condition=established --timeout=300s crd/installations.operator.tigera.io

$K apply --server-side \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.1/manifests/tigera-operator.yaml
$K -n tigera-operator rollout status deploy/tigera-operator --timeout=300s

cat > calico-installation.yaml <<'YAML'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      blockSize: 26
      cidr: 10.244.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
YAML
$K apply -f calico-installation.yaml

echo "esperando a que Calico quede disponible..."
LISTO=""
for _ in $(seq 1 45); do
  LISTO=$($K get tigerastatus calico -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
  [ "$LISTO" = "True" ] && break
  sleep 10
done
if [ "$LISTO" != "True" ]; then
  echo "ERROR SUSTRATO-SIN-CNI: Calico nunca quedo disponible en este cluster."
  echo "Sin un CNI instalado los Pods no consiguen direccion IP y NADA de este"
  echo "laboratorio funciona. Revise: \$K get tigerastatus; \$K -n calico-system get pods"
  exit 1
fi
$K wait --for=condition=Ready nodes --all --timeout=300s

# -------------------------------------------------------------------------
# PRUEBA DEL SUSTRATO: no asumimos que el CNI aplica NetworkPolicy, lo MEDIMOS.
# Linea base abierta -> negacion total -> la sonda bloqueada TIENE que fallar.
# -------------------------------------------------------------------------
echo "midiendo si este cluster de verdad APLICA NetworkPolicy..."
BB=busybox:1.37@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
NG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de
$K create namespace prueba-del-celador
$K -n prueba-del-celador run servidor --image=$NG --labels=rol=servidor --port=80
$K -n prueba-del-celador run cliente  --image=$BB --command -- sleep 600
$K -n prueba-del-celador wait --for=condition=Ready pod --all --timeout=300s
IP_PRUEBA=$($K -n prueba-del-celador get pod servidor -o jsonpath='{.status.podIP}')

if ! $K -n prueba-del-celador exec cliente -- wget -q -T 5 -O- "http://$IP_PRUEBA" >/dev/null 2>&1; then
  echo "ERROR SUSTRATO-SIN-TRAFICO: la linea base fallo, un Pod no le habla a otro"
  echo "ni siquiera SIN politicas. El modelo de red de Kubernetes dice que deberia."
  echo "Revise el CNI antes de continuar: \$K -n calico-system get pods"
  $K delete namespace prueba-del-celador --wait=false
  exit 1
fi

cat > prueba-negar-todo.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prueba-negar-todo
  namespace: prueba-del-celador
spec:
  podSelector: {}
  policyTypes:
  - Ingress
YAML
$K apply -f prueba-negar-todo.yaml
sleep 10

if $K -n prueba-del-celador exec cliente -- wget -q -T 5 -O- "http://$IP_PRUEBA" >/dev/null 2>&1; then
  echo "ERROR SUSTRATO-SIN-NETWORKPOLICY: se aplico una politica de negacion total"
  echo "y el trafico SIGUIO pasando. Este cluster guarda los NetworkPolicy en la API"
  echo "pero no los aplica: es el celador de mentiras del Capitulo 15."
  echo "El Paso 3 de este laboratorio no probaria absolutamente nada asi."
  echo "Revise que el cluster se haya creado con disableDefaultCNI: true y que"
  echo "Calico este vivo: \$K get tigerastatus; \$K -n calico-system get pods"
  $K delete namespace prueba-del-celador --wait=false
  exit 1
fi
echo "OK: el sustrato APLICA NetworkPolicy (linea base paso, con negacion total fallo)."
$K delete namespace prueba-del-celador --wait=false

echo "instalando ingress-nginx controller-v1.15.1 (ultima version del proyecto, ya retirado)"
$K apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml
$K wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=300s

for ns in la-plazoleta la-galeria el-centro-comercial; do
  $K create namespace "$ns"
done

cat > el-domicilio-perdido.b64 <<'B64'
YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIG5hbWU6IGhl
bGFkZXJpYS1sYS1uaWV2ZQogIG5hbWVzcGFjZTogbGEtcGxhem9sZXRhCnNwZWM6CiAgcmVwbGlj
YXM6IDIKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBhcHA6IGhlbGFkZXJpYS1s
YS1uaWV2ZQogIHRlbXBsYXRlOgogICAgbWV0YWRhdGE6CiAgICAgIGxhYmVsczoKICAgICAgICBh
cHA6IGhlbGFkZXJpYS1sYS1uaWV2ZQogICAgICAgIHNlZGU6IG5vcnRlCiAgICBzcGVjOgogICAg
ICBjb250YWluZXJzOgogICAgICAtIG5hbWU6IHdlYgogICAgICAgIGltYWdlOiBuZ2lueDoxLjI5
LWFscGluZUBzaGEyNTY6NTYxNjg3ODI5MWEyZWVkNTk0YWVlOGRiNGRhZGU1ODc4Y2Y3ZWRjYjQ3
NWU1OTE5MzkwNGIxOThkOWI4MzBkZQogICAgICAgIHBvcnRzOgogICAgICAgIC0gY29udGFpbmVy
UG9ydDogODAKLS0tCmFwaVZlcnNpb246IHYxCmtpbmQ6IFNlcnZpY2UKbWV0YWRhdGE6CiAgbmFt
ZTogZG9taWNpbGlvcy1oZWxhZGVyaWEKICBuYW1lc3BhY2U6IGxhLXBsYXpvbGV0YQpzcGVjOgog
IHR5cGU6IENsdXN0ZXJJUAogIHNlbGVjdG9yOgogICAgYXBwOiBoZWxhZGVyaWEtbGEtbmlldmUK
ICAgIHNlZGU6IHN1cgogIHBvcnRzOgogIC0gbmFtZTogaHR0cAogICAgcG9ydDogODAKICAgIHRh
cmdldFBvcnQ6IDgwCiAgICBwcm90b2NvbDogVENQCg==
B64
base64 -d el-domicilio-perdido.b64 | $K apply -f -
$K -n la-plazoleta rollout status deploy/heladeria-la-nieve --timeout=300s

echo "espacio de trabajo listo en ~/ckad-lab/p05"
echo "kubeconfig privado: ~/ckad-lab/p05/kubeconfig (su ~/.kube/config no fue tocado)"
