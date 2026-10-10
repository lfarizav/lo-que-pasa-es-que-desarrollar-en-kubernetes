#!/usr/bin/env bash
# lab-part-05 step 2 (10 pts)
# Generated from the book's lab source. Do not edit here.
set -euo pipefail
# Some commands in this lab may fail on purpose: the failure is the lesson. Fail-fast is
# therefore switched off from here and the script reports through the grader.
set +e

cd ~/ckad-lab/p05
K="kubectl --kubeconfig $HOME/ckad-lab/p05/kubeconfig"

# 1. Ver el sintoma: el Service existe, el EndpointSlice existe, y esta vacio.
$K -n la-plazoleta get svc domicilios-heladeria
$K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios-heladeria
$K -n la-plazoleta get pods -l app=heladeria-la-nieve --show-labels

# 2. Poner las dos verdades una al lado de la otra.
$K -n la-plazoleta get svc domicilios-heladeria -o jsonpath='{.spec.selector}{"\n"}'
$K -n la-plazoleta get deploy heladeria-la-nieve -o jsonpath='{.spec.template.metadata.labels}{"\n"}'

# 3. Arreglarlo. ESTA es la ruta canonica: el papel viejo es el que se corrige.
$K -n la-plazoleta patch svc domicilios-heladeria \
  --type=json -p='[{"op":"replace","path":"/spec/selector/sede","value":"norte"}]'

# (La otra ruta valida seria mover el Deployment a la sede sur. Tambien pasa,
#  siempre que las dos partes queden con la MISMA sede y el Service quede con
#  endpoints; el archivo de respuesta tiene que declarar cual lado movio usted.)
# $K -n la-plazoleta patch deploy heladeria-la-nieve \
#   --type=json -p='[{"op":"replace","path":"/spec/template/metadata/labels/sede","value":"sur"}]'
# $K -n la-plazoleta rollout status deploy/heladeria-la-nieve --timeout=300s

$K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios-heladeria

# The answer file the lab asks you to type, written from the live cluster
# (this script moved the Service, the canonical route):
cat > 02-respuesta.txt <<EOF
SEDE_ACORDADA=$($K -n la-plazoleta get svc domicilios-heladeria -o jsonpath='{.spec.selector.sede}')
LADO_QUE_CAMBIE=servicio
ENDPOINTS_HELADERIA=$($K -n la-plazoleta get endpointslices -l kubernetes.io/service-name=domicilios-heladeria -o jsonpath='{range .items[*]}{range .endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}{end}' | grep -c .)
EOF
cat 02-respuesta.txt
