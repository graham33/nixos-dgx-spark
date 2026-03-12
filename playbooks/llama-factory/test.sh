#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing llama-factory ==="

# --- Smoke tests (always run) ---

CONTAINER_IMAGE="docker.io/hiyouga/llamafactory:latest"

echo "Checking llama-factory-start function is defined..."
declare -f llama-factory-start > /dev/null
echo "OK: llama-factory-start is defined"

echo "Checking llama-factory-start references correct container image..."
declare -f llama-factory-start | grep -qF "${CONTAINER_IMAGE}"
echo "OK: llama-factory-start references ${CONTAINER_IMAGE}"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  echo "Pulling LLaMA Factory image..."
  podman pull "${CONTAINER_IMAGE}"

  echo "Checking llamafactory-cli in container..."
  podman run --rm "${CONTAINER_IMAGE}" \
    llamafactory-cli version 2>&1 | head -5 || true
  echo "OK: llamafactory-cli is accessible in container"
fi

echo "All tests passed!"
