#!/usr/bin/env bash
# lab-part-04 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

KC="$HOME/ckad-lab/p04/kubeconfig"
W="$HOME/ckad-lab/p04"
NODO_IMG="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
BB="busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0"

for tool in kind kubectl docker; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FALTA: $tool - instalelo antes de empezar."; exit 1; }
done

mkdir -p "$W"
cat > "$W/kind.yaml" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
YAML

kind get clusters 2>/dev/null | grep -qx ckad-p04 || \
  kind create cluster --name ckad-p04 \
    --kubeconfig "$KC" \
    --image "$NODO_IMG" \
    --config "$W/kind.yaml" \
    --wait 180s

test -f "$KC" || kind export kubeconfig --name ckad-p04 --kubeconfig "$KC"
chmod 600 "$KC"
kubectl --kubeconfig "$KC" wait --for=condition=Ready node --all --timeout=180s

kubectl --kubeconfig "$KC" get namespace sonda-p04 >/dev/null 2>&1 || \
  kubectl --kubeconfig "$KC" create namespace sonda-p04 >/dev/null

# ---------- prueba de sustrato 1: el ResourceQuota se hace cumplir ----------
kubectl --kubeconfig "$KC" apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: sonda-cupo
  namespace: sonda-p04
spec:
  hard:
    requests.cpu: 100m
    requests.memory: 64Mi
    limits.cpu: 200m
    limits.memory: 128Mi
    pods: "2"
YAML
sleep 3
SALIDA=$(kubectl --kubeconfig "$KC" -n sonda-p04 run sonda-sin-medidas \
  --image="$BB" --restart=Never --command -- sleep 60 2>&1 || true)
if ! echo "$SALIDA" | grep -q "failed quota"; then
  echo "ERROR SUSTRATO_SIN_CUOTA: este cluster acepto un Pod sin requests ni limits en un namespace que tiene un ResourceQuota de computo. El Paso 1 entero se trata de dimensionar un Pod para que quepa en un cupo, y sin admision de cuota todo lo que sigue seria decoracion. Lo que devolvio el API server fue: $SALIDA. Revise que ResourceQuota este en --enable-admission-plugins del kube-apiserver: kubectl --kubeconfig $KC -n kube-system get pod -l component=kube-apiserver -o yaml | grep admission"
  exit 1
fi
echo "prueba de sustrato 1 OK: el ResourceQuota rechaza de verdad un Pod sin medidas."

# ---------- prueba de sustrato 2: RBAC autoriza de verdad ----------
RESP=$(kubectl --kubeconfig "$KC" auth can-i delete secrets -n sonda-p04 \
  --as=system:serviceaccount:sonda-p04:nadie 2>/dev/null || true)
if [ "$RESP" != "no" ]; then
  echo "ERROR SUSTRATO_SIN_RBAC: al preguntar si una ServiceAccount inexistente puede borrar Secrets, este cluster respondio '$RESP' en vez de 'no'. Eso significa que el modo de autorizacion no esta negando nada, y el Paso 4 completo, que se califica con kubectl auth can-i por los dos lados, no probaria nada. Revise: kubectl --kubeconfig $KC -n kube-system get pod -l component=kube-apiserver -o yaml | grep authorization-mode"
  exit 1
fi
echo "prueba de sustrato 2 OK: RBAC responde que no a lo que nadie autorizo."

# ---------- prueba de sustrato 3: runAsNonRoot se hace cumplir ----------
kubectl --kubeconfig "$KC" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: sonda-de-root
  namespace: sonda-p04
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: c
    image: $BB
    command: ["sh","-c","sleep 60"]
    resources:
      requests: {cpu: 50m, memory: 32Mi}
      limits: {cpu: 100m, memory: 64Mi}
YAML
RAZON=""
for i in $(seq 1 20); do
  RAZON=$(kubectl --kubeconfig "$KC" -n sonda-p04 get pod sonda-de-root \
    -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
  [ "$RAZON" = "CreateContainerConfigError" ] && break
  sleep 3
done
if [ "$RAZON" != "CreateContainerConfigError" ]; then
  echo "ERROR SUSTRATO_SIN_SECURITYCONTEXT: un Pod con runAsNonRoot true sobre una imagen que corre como root no quedo en CreateContainerConfigError; quedo en '$RAZON'. El Paso 3 califica el uniforme obligatorio del Capitulo 12 leyendo la identidad viva del proceso, y si el kubelet no hace cumplir runAsNonRoot ese paso no significa nada. Revise: kubectl --kubeconfig $KC -n sonda-p04 describe pod sonda-de-root"
  kubectl --kubeconfig "$KC" delete namespace sonda-p04 --wait=false >/dev/null 2>&1
  exit 1
fi
echo "prueba de sustrato 3 OK: el kubelet impide arrancar como root cuando se le prohibe."
kubectl --kubeconfig "$KC" delete namespace sonda-p04 --wait=false >/dev/null 2>&1

# ---------- la plaza ----------
kubectl --kubeconfig "$KC" get namespace plaza >/dev/null 2>&1 || \
  kubectl --kubeconfig "$KC" create namespace plaza >/dev/null

kubectl --kubeconfig "$KC" apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cupo-de-la-plaza
  namespace: plaza
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "8"
---
apiVersion: v1
kind: Pod
metadata:
  name: puesto-de-jugos
  namespace: plaza
spec:
  containers:
  - name: jugos
    image: $BB
    command: ["sh","-c","sleep 86400"]
    resources:
      requests:
        cpu: 400m
        memory: 400Mi
      limits:
        cpu: 800m
        memory: 800Mi
YAML

kubectl --kubeconfig "$KC" -n plaza get secret caja-fuerte >/dev/null 2>&1 || \
  kubectl --kubeconfig "$KC" -n plaza create secret generic caja-fuerte \
    --from-literal=clave='la-clave-de-la-registradora-77' >/dev/null

kubectl --kubeconfig "$KC" apply -f - >/dev/null <<'YAML'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: pedidos.plaza.example.com
spec:
  group: plaza.example.com
  scope: Namespaced
  names:
    plural: pedidos
    singular: pedido
    kind: Pedido
    shortNames: ["ped"]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              mesa:
                type: string
              plato:
                type: string
            required: ["mesa", "plato"]
YAML
kubectl --kubeconfig "$KC" wait --for=condition=Established \
  crd/pedidos.plaza.example.com --timeout=60s >/dev/null
kubectl --kubeconfig "$KC" apply -f - >/dev/null <<'YAML'
apiVersion: plaza.example.com/v1
kind: Pedido
metadata:
  name: pedido-de-la-mesa-4
  namespace: plaza
spec:
  mesa: "4"
  plato: ajiaco-santafereno
YAML

test -f "$W/puesto-de-frutas.yaml" || cat > "$W/puesto-de-frutas.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: puesto-de-frutas
  namespace: plaza
spec:
  containers:
  - name: frutas
    image: $BB
    command: ["sh","-c","sleep 86400"]
    resources:
      requests:
        cpu: "1"
        memory: 1Gi
      limits:
        cpu: "2"
        memory: 2Gi
YAML

kubectl --kubeconfig "$KC" -n plaza wait --for=condition=Ready pod/puesto-de-jugos --timeout=180s

echo "espacio de trabajo listo en $W"
echo "cluster ckad-p04 con kubeconfig privado en $KC"
echo "namespace de trabajo: plaza"
kubectl --kubeconfig "$KC" -n plaza get resourcequota cupo-de-la-plaza
echo "el manifiesto que le dejaron sin medir esta en $W/puesto-de-frutas.yaml"
