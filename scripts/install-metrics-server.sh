#!/usr/bin/env bash
# Installs metrics-server, which the HPA needs to read Pod CPU usage.
# Docker Desktop's kubelet uses a self-signed certificate, so TLS verification
# against the kubelet is disabled with --kubelet-insecure-tls (local clusters only).
set -euo pipefail

VERSION="v0.7.2"

kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${VERSION}/components.yaml"

kubectl patch deployment metrics-server -n kube-system --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
