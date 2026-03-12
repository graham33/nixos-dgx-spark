#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing nemo-finetune ==="

# --- Smoke tests (always run) ---

echo "Checking nemo-start shell function is defined..."
declare -f nemo-start > /dev/null
echo "OK: nemo-start is defined"

echo "Checking nemo-start function references correct container image..."
declare -f nemo-start | grep -q "nvcr.io/nvidia/pytorch:25.11-py3"
echo "OK: nemo-start references nvcr.io/nvidia/pytorch:25.11-py3"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  CONTAINER_IMAGE="nvcr.io/nvidia/pytorch:25.11-py3"
  echo "Checking if NeMo container image is available locally..."
  if podman image exists "${CONTAINER_IMAGE}" 2>/dev/null; then
    echo "Container image found: ${CONTAINER_IMAGE}"
    echo "Testing container Python version..."
    podman run --rm \
      --device nvidia.com/gpu=all \
      "${CONTAINER_IMAGE}" \
      python3 --version
    echo "OK: Container Python works"
  else
    echo "SKIP: Container image ${CONTAINER_IMAGE} not available locally (run 'podman pull ${CONTAINER_IMAGE}' to enable full tests)"
  fi
fi

echo "All tests passed!"
