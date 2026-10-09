#!/usr/bin/env bash
# lab-part-01 - setup
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

mkdir -p ~/ckad-lab/p01/receta
cd ~/ckad-lab/p01

for herramienta in kind kubectl docker jq; do
  command -v "$herramienta" >/dev/null 2>&1 || echo "FALTA: $herramienta - instalelo antes de continuar."
done

kind create cluster --name ckad-p01 \
  --kubeconfig ~/ckad-lab/p01/kubeconfig \
  --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5

KC="$HOME/ckad-lab/p01/kubeconfig"
K="kubectl --kubeconfig $KC --context kind-ckad-p01"
BUSYBOX=busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0

$K wait --for=condition=Ready nodes --all --timeout=180s

for NEGOCIO in la-cocina los-encargos la-madrugada la-nevera; do
  $K create namespace "$NEGOCIO"
done

cat > ~/ckad-lab/p01/receta/carta.html <<'CARTA'
la-carta-del-restaurante-v1
CARTA

cat > ~/ckad-lab/p01/receta/Dockerfile <<'RECETA'
FROM busybox:1.37.0@sha256:9db7b59979c38555a39def84a31fb98b5296952f9e3afd4f6f11f05b07adfab0
RUN mkdir -p /carta
COPY carta.html /carta/index.html
EXPOSE 8080
CMD ["httpd","-f","-p","8080","-h","/carta"]
RECETA

echo "PRUEBA DE SUSTRATO 1 de 2: el nodo puede traer la imagen fijada por digest"
$K -n la-cocina run prueba-de-sustrato --restart=Never \
  --image="$BUSYBOX" --command -- sh -c 'exit 0'
if ! $K -n la-cocina wait --for=jsonpath='{.status.phase}'=Succeeded \
     pod/prueba-de-sustrato --timeout=240s; then
  echo "ERROR DE SUSTRATO: SIN-IMAGEN-BUSYBOX."
  echo "El containerd del nodo no pudo traer $BUSYBOX desde docker.io."
  echo "Los Pasos 2, 3 y 4 son decoracion hasta que eso funcione."
  $K -n la-cocina describe pod prueba-de-sustrato | tail -20
  exit 1
fi
$K -n la-cocina delete pod prueba-de-sustrato

echo "PRUEBA DE SUSTRATO 2 de 2: kind load docker-image funciona en esta maquina"
printf 'FROM %s\nRUN true\n' "$BUSYBOX" > ~/ckad-lab/p01/Dockerfile.sustrato
if ! docker build -q -t ckad-sustrato:0 \
     -f ~/ckad-lab/p01/Dockerfile.sustrato ~/ckad-lab/p01 >/dev/null; then
  echo "ERROR DE SUSTRATO: DOCKER-NO-CONSTRUYE. El Paso 1 es imposible sin esto."
  exit 1
fi
if ! kind load docker-image ckad-sustrato:0 --name ckad-p01 >/dev/null 2>&1; then
  echo "ERROR DE SUSTRATO: KIND-LOAD-NO-FUNCIONA."
  echo "Su docker exporta una imagen multiplataforma que kind no sabe importar."
  echo "Reconstruya con --platform linux/amd64 o con DOCKER_BUILDKIT=0 y repita."
  exit 1
fi
docker exec ckad-p01-control-plane crictl rmi docker.io/library/ckad-sustrato:0 >/dev/null 2>&1
docker image rm ckad-sustrato:0 >/dev/null 2>&1
rm -f ~/ckad-lab/p01/Dockerfile.sustrato
echo "las dos pruebas de sustrato pasaron"

kubectl config get-contexts

echo "espacio de trabajo listo en ~/ckad-lab/p01"
echo "si la linea de arriba menciona ckad-p01, el aislamiento fallo: revise el --kubeconfig"
