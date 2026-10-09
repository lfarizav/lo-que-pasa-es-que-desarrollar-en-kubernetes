#!/usr/bin/env bash
# lab-part-01 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name ckad-p01 \
  --kubeconfig ~/ckad-lab/p01/kubeconfig

docker image rm la-receta:1.0 2>/dev/null

rm -rf ~/ckad-lab/p01

echo "cluster ckad-p01 eliminado y workspace borrado"
echo "sus otros clusteres de kind siguen intactos:"
kind get clusters
