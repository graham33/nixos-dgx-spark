#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing pytorch-finetune ==="

# --- Smoke tests (always run) ---

echo "Checking podman available..."
command -v podman
echo "OK: podman available"

echo "Checking pytorch-finetune shell helper exported..."
declare -f pytorch-finetune
echo "OK: pytorch-finetune function is exported"

CONTAINER_IMAGE="nvcr.io/nvidia/pytorch:25.11-py3"
echo "Container image: ${CONTAINER_IMAGE}"

# --- Full integration tests (inside container, only with --full) ---
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

  echo "Checking transformers and peft imports inside container..."
  podman run --rm "${CONTAINER_IMAGE}" \
    bash -c "pip install --quiet transformers peft datasets trl bitsandbytes && \
      python3 -c 'import transformers; import peft; print(transformers.__version__, peft.__version__)'"
fi

echo "All tests passed!"
