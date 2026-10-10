#!/usr/bin/env bash
# lab-part-05 step 4 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p05
K="kubectl --kubeconfig $HOME/ckad-lab/p05/kubeconfig"
IMG=nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

cat > locales.yaml <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: contenido-ropa
  namespace: el-centro-comercial
data:
  index.html: |
    LOCAL DE ROPA
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: contenido-helados
  namespace: el-centro-comercial
data:
  index.html: |
    LOCAL DE HELADOS
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-de-ropa
  namespace: el-centro-comercial
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-de-ropa
  template:
    metadata:
      labels:
        app: local-de-ropa
    spec:
      containers:
      - name: web
        image: $IMG
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/ropa
      volumes:
      - name: html
        configMap:
          name: contenido-ropa
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: local-de-helados
  namespace: el-centro-comercial
spec:
  replicas: 1
  selector:
    matchLabels:
      app: local-de-helados
  template:
    metadata:
      labels:
        app: local-de-helados
    spec:
      containers:
      - name: web
        image: $IMG
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/helados
      volumes:
      - name: html
        configMap:
          name: contenido-helados
---
apiVersion: v1
kind: Service
metadata:
  name: local-de-ropa
  namespace: el-centro-comercial
spec:
  selector:
    app: local-de-ropa
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: local-de-helados
  namespace: el-centro-comercial
spec:
  selector:
    app: local-de-helados
  ports:
  - name: http
    port: 80
    targetPort: 80
YAML

$K apply -f locales.yaml
$K -n el-centro-comercial rollout status deploy/local-de-ropa --timeout=300s
$K -n el-centro-comercial rollout status deploy/local-de-helados --timeout=300s

$K get ingressclass
$K get ingressclass nginx -o jsonpath='{.spec.controller}{"\n"}'

cat > directorio.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: directorio-de-la-entrada
  namespace: el-centro-comercial
spec:
  ingressClassName: nginx
  rules:
  - host: centrocomercial.local
    http:
      paths:
      - path: /ropa
        pathType: Prefix
        backend:
          service:
            name: local-de-ropa
            port:
              number: 80
      - path: /helados
        pathType: Prefix
        backend:
          service:
            name: local-de-helados
            port:
              number: 80
YAML

$K apply -f directorio.yaml
$K -n el-centro-comercial get ingress directorio-de-la-entrada
$K -n el-centro-comercial describe ingress directorio-de-la-entrada

# El controlador no recarga sus reglas en el mismo instante del apply: si usted
# hace curl de una, le contesta 404 y parece que el Ingress no sirviera.
echo "esperando a que el controlador cargue las reglas nuevas..."
for _ in $(seq 1 30); do
  CODIGO=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
    -H 'Host: centrocomercial.local' http://localhost:8085/ropa/ 2>/dev/null)
  [ "$CODIGO" = "200" ] && break
  sleep 2
done

curl -sS -H 'Host: centrocomercial.local' http://localhost:8085/ropa/
curl -sS -H 'Host: centrocomercial.local' http://localhost:8085/helados/
curl -sS -o /dev/null -w 'con otro host: HTTP %{http_code}\n' \
  -H 'Host: no-existe-este-centro.local' http://localhost:8085/ropa/

# The answer file the lab asks you to type, written from the live cluster and the controller:
cat > 04-respuesta.txt <<EOF
CLASE_DEL_DIRECTORIO=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.ingressClassName}')
HOST_DEL_DIRECTORIO=$($K -n el-centro-comercial get ingress directorio-de-la-entrada -o jsonpath='{.spec.rules[0].host}')
HTTP_HOST_DESCONOCIDO=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 -H 'Host: no-existe-este-centro.local' http://localhost:8085/ropa/)
EOF
cat 04-respuesta.txt
