#!/usr/bin/env bash
# lab-part-03 step 3 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

W="$HOME/ckad-lab/p03"; K="kubectl --kubeconfig $W/kubeconfig"

# 1. El sintoma raro: el Pod dice 1/1 Running y aun asi nadie es atendido.
#    La unica pista en la tabla es la columna RESTARTS.
$K -n el-catalogo get pods
$K -n default exec mandadero -- curl -s -o /dev/null -w 'codigo %{http_code}\n' --max-time 8 \
  http://catalogo.el-catalogo.svc.cluster.local/ || true

# 2. El libro de quejas de HOY: vacio. La aplicacion no se esta quejando de nada.
POD=$($K -n el-catalogo get pod -l app=catalogo -o jsonpath='{.items[0].metadata.name}')
$K -n el-catalogo logs "$POD"

# 3. El libro de la vuelta pasada. ANOTE ESTE MENSAJE ANTES DE ARREGLAR NADA:
#    se va con el Pod en cuanto usted haga el rollout.
$K -n el-catalogo logs "$POD" --previous | tee "$W/03-bitacora-anterior.log"

# 4. Los examenes: que variable pide el contenedor y de donde la esta sacando.
$K -n el-catalogo get deploy catalogo \
  -o jsonpath='{.spec.template.spec.containers[0].env[0]}{"\n"}'
$K -n el-catalogo get configmap el-inventario -o jsonpath='{.data}{"\n"}'

# 5. Recetar: la variable se sigue leyendo del ConfigMap, pero de la llave que
#    SI existe. El valor nunca se escribe a mano en el manifiesto.
$K -n el-catalogo patch deployment catalogo --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env/0/valueFrom/configMapKeyRef/key","value":"PAGINA_CATALOGO"}]'

# 6. Comprobar el alta: el Pod arranca sin reiniciarse y el catalogo abre.
$K -n el-catalogo rollout status deployment/catalogo --timeout=240s
$K -n el-catalogo get pods
# El Pod nuevo puede tardar unos segundos en entrar al directorio del Service.
for i in 1 2 3 4 5 6; do
  $K -n default exec mandadero -- curl -s --max-time 8 \
    http://catalogo.el-catalogo.svc.cluster.local/ && break
  sleep 5
done

# The answer file the lab asks you to type, written from the saved log of the previous
# instance, the manifest the setup applied, and the live Deployment:
CMREF=$($K -n el-catalogo get deploy catalogo -o jsonpath='{.spec.template.spec.containers[0].env[0].valueFrom.configMapKeyRef}')
cat > "$W/03-respuesta.txt" <<EOF
MENSAJE_FATAL=$(grep -m1 '^FATAL' "$W/03-bitacora-anterior.log")
LLAVE_FANTASMA=$(sed -n 's/^ *key: *//p' "$W/averias/paso3.yaml" | head -1)
CAMPO_QUE_LO_TAPO=$(echo "$CMREF" | sed -n 's/.*"\([a-zA-Z]*\)":true.*/\1/p')
EOF
cat "$W/03-respuesta.txt"
