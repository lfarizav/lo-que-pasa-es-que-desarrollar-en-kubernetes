#!/usr/bin/env bash
# lab-part-04 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name ckad-p04 --kubeconfig "$HOME/ckad-lab/p04/kubeconfig"
rm -rf "$HOME/ckad-lab/p04"
echo "cluster ckad-p04 eliminado y workspace borrado; ningun otro cluster de kind fue tocado y su kubeconfig de siempre nunca se modifico"
