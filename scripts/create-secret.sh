#!/usr/bin/env bash
# Creates (or updates) the postgres-secret Secret from a local .env file,
# so no credential is ever written to a versioned manifest.
set -euo pipefail

ENV_FILE="${1:-.env}"
NAMESPACE="kubernetes-challenge"

if [ ! -f "$ENV_FILE" ]; then
  echo "error: $ENV_FILE not found. Copy .env.example to .env and set a password." >&2
  exit 1
fi

# Strip CRLF so a .env saved on Windows doesn't leave '\r' in the values
CLEAN_ENV="$(mktemp)"
trap 'rm -f "$CLEAN_ENV"' EXIT
tr -d '\r' < "$ENV_FILE" > "$CLEAN_ENV"

kubectl create secret generic postgres-secret \
  --namespace "$NAMESPACE" \
  --from-env-file="$CLEAN_ENV" \
  --dry-run=client -o yaml | kubectl apply -f -
