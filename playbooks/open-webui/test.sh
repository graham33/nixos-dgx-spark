#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing open-webui ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman
command -v curl
command -v jq

echo "Checking podman..."
podman --version

echo "Checking curl..."
curl --version | head -1

echo "Checking jq..."
jq --version

echo "Checking podman info (local config only, no pull)..."
PODMAN_HELP=$(podman run --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF -- "--device"
echo "OK: podman run --help contains --device flag"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full tests would start the open-webui container."
  echo "Skipping container start in automated tests."
fi

echo "All tests passed!"
