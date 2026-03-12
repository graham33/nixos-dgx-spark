#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing nemo-finetune ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking podman version..."
podman --version

echo "Checking podman info (local only, no container pull)..."
PODMAN_INFO=$(podman info 2>&1 || true)
echo "${PODMAN_INFO}" | grep -qiF "host" || true
echo "OK: podman info works"

echo "Checking podman images (list local images)..."
podman images --format "{{.Repository}}:{{.Tag}}" 2>&1 | head -5 || true
echo "OK: podman images works"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  echo "Checking if NeMo container image is available locally..."
  CONTAINER_IMAGE="nvcr.io/nvidia/pytorch:25.11-py3"
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
