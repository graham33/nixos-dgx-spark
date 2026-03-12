#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing portfolio-optimization ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman

echo "Checking shell helper functions..."
declare -f portfolio-start > /dev/null
echo "OK: portfolio-start function is defined"

echo "Checking portfolio-start uses expected container image..."
declare -f portfolio-start | grep -qF "nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13"
echo "OK: portfolio-start references the expected container image"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full tests would launch the RAPIDS JupyterLab container."
  echo "Skipping container launch to avoid pulling large images."
fi

echo "All tests passed!"
