#!/usr/bin/env bash
# lab-part-05 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name ckad-p05 --kubeconfig "$HOME/ckad-lab/p05/kubeconfig"
rm -rf ~/ckad-lab/p05
echo "cluster ckad-p05 eliminado y workspace borrado; ningun otro cluster fue tocado"
