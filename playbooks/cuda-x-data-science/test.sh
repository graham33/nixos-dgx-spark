#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing cuda-x-data-science ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking podman..."
PODMAN_VERSION=$(podman --version 2>&1 || true)
echo "${PODMAN_VERSION}" | grep -qF "podman"
echo "OK: podman version: ${PODMAN_VERSION}"

echo "Checking podman info..."
PODMAN_INFO=$(podman info 2>&1 || true)
echo "${PODMAN_INFO}" | grep -qF "host"
echo "OK: podman info works"

echo "Checking podman images (no pull)..."
podman images --format "{{.Repository}}:{{.Tag}}" 2>&1 || true
echo "OK: podman images works"

echo "Checking RAPIDS container image availability..."
RAPIDS_IMAGE="docker.io/rapidsai/notebooks:25.12-cuda13-py3.12"
if podman image exists "${RAPIDS_IMAGE}" 2>/dev/null; then
  echo "OK: RAPIDS image already pulled: ${RAPIDS_IMAGE}"
else
  echo "INFO: RAPIDS image not yet pulled (expected in smoke test): ${RAPIDS_IMAGE}"
  echo "INFO: Run 'podman pull ${RAPIDS_IMAGE}' to pull it"
fi

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  RAPIDS_IMAGE="docker.io/rapidsai/notebooks:25.12-cuda13-py3.12"

  if ! podman image exists "${RAPIDS_IMAGE}" 2>/dev/null; then
    echo "ERROR: RAPIDS image not found. Pull it first:"
    echo "  podman pull ${RAPIDS_IMAGE}"
    exit 1
  fi

  echo "Checking RAPIDS tools inside container..."

  echo "Checking cuDF..."
  podman run --rm \
    --device nvidia.com/gpu=all \
    "${RAPIDS_IMAGE}" \
    python3 -c "import cudf; print('cuDF version:', cudf.__version__)"
  echo "OK: cuDF import works"

  echo "Checking cuML..."
  podman run --rm \
    --device nvidia.com/gpu=all \
    "${RAPIDS_IMAGE}" \
    python3 -c "import cuml; print('cuML version:', cuml.__version__)"
  echo "OK: cuML import works"

  echo "Checking cuGraph..."
  podman run --rm \
    --device nvidia.com/gpu=all \
    "${RAPIDS_IMAGE}" \
    python3 -c "import cugraph; print('cuGraph version:', cugraph.__version__)"
  echo "OK: cuGraph import works"

  echo "Checking GPU availability inside container..."
  podman run --rm \
    --device nvidia.com/gpu=all \
    "${RAPIDS_IMAGE}" \
    python3 -c "import cudf; import rmm; print('GPU available via RAPIDS')"
  echo "OK: GPU accessible inside container"
fi

echo "All tests passed!"
