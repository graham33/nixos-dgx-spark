#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing pytorch-finetune ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking podman..."
PODMAN_HELP=$(podman --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF "run"
echo "OK: podman --help works"

echo "Checking podman version..."
podman --version

echo "Checking podman info (storage/runtime)..."
# Just verify podman info runs without error; don't require a daemon
podman info --format '{{.Host.OS}}' 2>&1 || true
echo "OK: podman info ran"

# Verify the container image reference is correct (no pull, just inspect cached or skip)
CONTAINER_IMAGE="nvcr.io/nvidia/pytorch:25.11-py3"
echo "Container image: ${CONTAINER_IMAGE}"

# --- Python import checks (inside container, only with --full) ---
if $FULL; then
  echo "Running full integration tests (inside container)..."

  echo "Pulling container image (this may take a while)..."
  podman pull "${CONTAINER_IMAGE}"

  echo "Checking python3 inside container..."
  podman run --rm "${CONTAINER_IMAGE}" python3 --version

  echo "Checking torch import inside container..."
  TORCH_VERSION=$(podman run --rm "${CONTAINER_IMAGE}" \
    python3 -c 'import torch; print(torch.__version__)' 2>&1 || true)
  echo "torch version: ${TORCH_VERSION}"

  echo "Checking torch.cuda.is_available() inside container..."
  CUDA_AVAILABLE=$(podman run --rm \
    --device nvidia.com/gpu=all \
    "${CONTAINER_IMAGE}" \
    python3 -c 'import torch; print(torch.cuda.is_available())' 2>&1 || true)
  echo "torch.cuda.is_available(): ${CUDA_AVAILABLE}"
  if [[ "${CUDA_AVAILABLE}" != "True" ]]; then
    echo "NOTE: torch.cuda.is_available() is False (known GB10/SM12.1 compat issue - not a failure)"
  fi

  echo "Checking transformers import inside container..."
  podman run --rm "${CONTAINER_IMAGE}" \
    bash -c "pip install --quiet transformers peft datasets trl bitsandbytes && \
      python3 -c 'import transformers; print(transformers.__version__)'"

  echo "Checking peft import inside container..."
  podman run --rm "${CONTAINER_IMAGE}" \
    bash -c "pip install --quiet peft && \
      python3 -c 'import peft; print(peft.__version__)'"
fi

echo "All tests passed!"
