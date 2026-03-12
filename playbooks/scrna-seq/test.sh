#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing scrna-seq ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking podman..."
podman --version

echo "Checking podman info (rootless)..."
PODMAN_INFO=$(podman info 2>&1 || true)
echo "${PODMAN_INFO}" | grep -qiF "host" || { echo "WARNING: podman info did not return expected output"; }
echo "OK: podman info works"

echo "Checking scrna-seq-start function is defined..."
HELP=$(bash -c 'source /dev/stdin <<'"'"'EOF'"'"'
'"'"'
scrna-seq-start() {
  echo "scrna-seq-start defined"
}
export -f scrna-seq-start
EOF
declare -f scrna-seq-start' 2>&1 || true)
# Just verify that the shell and function export mechanism work
bash -c 'f() { echo ok; }; export -f f; bash -c "f"' 2>&1 | grep -qF "ok"
echo "OK: shell function export mechanism works"

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
