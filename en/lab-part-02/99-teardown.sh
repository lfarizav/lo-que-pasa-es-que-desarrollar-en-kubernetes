#!/usr/bin/env bash
# lab-part-02 - teardown
# Generated from the book's lab source. Do not edit here.
set -euo pipefail

kind delete cluster --name ckad-p02
rm -rf ~/ckad-lab/p02
echo "cluster ckad-p02 eliminado y workspace borrado"
echo "sus otros clusters, su ~/.kube/config y su configuracion de helm quedaron intactos: este laboratorio nunca los toco"
