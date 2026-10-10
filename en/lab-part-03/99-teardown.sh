#!/usr/bin/env bash
# lab-part-03 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name ckad-p03 \
  --kubeconfig "$HOME/ckad-lab/p03/kubeconfig" 2>/dev/null
rm -rf "$HOME/ckad-lab/p03"
echo "cluster ckad-p03 eliminado y workspace ~/ckad-lab/p03 borrado"
echo "ningun otro cluster, contexto ni contenedor de la maquina fue tocado"
