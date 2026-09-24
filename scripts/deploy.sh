#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kubernetes-challenge"
cd "$(dirname "$0")/.."

kubectl apply -f k8s/00-namespace.yaml
./scripts/create-secret.sh
kubectl apply -f k8s/

kubectl rollout status deployment/postgres -n "$NAMESPACE" --timeout=180s
kubectl exec -i deployment/postgres -n "$NAMESPACE" -- \
  sh -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < sql/init.sql

kubectl rollout status deployment/postgrest -n "$NAMESPACE" --timeout=180s
kubectl get all -n "$NAMESPACE"
