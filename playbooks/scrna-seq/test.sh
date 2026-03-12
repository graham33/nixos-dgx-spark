#!/usr/bin/env bash
set -euo pipefail
# Handle SIGPIPE gracefully (e.g. from grep pipelines)
trap '' PIPE

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing scrna-seq ==="

# --- Smoke tests (always run) ---

# Verify podman is available (the only package provided by this devshell)
command -v podman

# Check that the shellHook exported the scrna-seq-start helper function
echo "Checking scrna-seq-start function is exported..."
declare -f scrna-seq-start > /dev/null
echo "OK: scrna-seq-start is exported"

# Verify the function references the expected container image
echo "Checking scrna-seq-start references the RAPIDS container image..."
declare -f scrna-seq-start | grep -qF "nvcr.io/nvidia/rapidsai/notebooks"
echo "OK: scrna-seq-start references the RAPIDS container image"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  CONTAINER_IMAGE="nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13"

  echo "Pulling container image (this may take a while)..."
  podman pull "${CONTAINER_IMAGE}"

  echo "Testing Python imports in container..."
  podman run --rm \
    "${CONTAINER_IMAGE}" \
    python3 -c "
import scanpy; print('scanpy:', scanpy.__version__)
import anndata; print('anndata:', anndata.__version__)
print('OK: key Python packages importable')
"

  echo "Testing rapids-singlecell import in container..."
  podman run --rm \
    "${CONTAINER_IMAGE}" \
    python3 -c "
import rapids_singlecell; print('rapids_singlecell:', rapids_singlecell.__version__)
print('OK: rapids-singlecell importable')
" || echo "WARNING: rapids-singlecell not importable (may need GPU)"

fi

echo "All tests passed!"
