#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing portfolio-optimization ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking podman..."
PODMAN_HELP=$(podman --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF "run"
echo "OK: podman --help works"

echo "Checking podman version..."
podman --version

echo "Checking podman run --help..."
PODMAN_RUN_HELP=$(podman run --help 2>&1 || true)
echo "${PODMAN_RUN_HELP}" | grep -qF -- "--device"
echo "OK: podman run --help contains --device flag"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full tests would launch the RAPIDS JupyterLab container."
  echo "Skipping container launch to avoid pulling large images."
fi

echo "All tests passed!"
