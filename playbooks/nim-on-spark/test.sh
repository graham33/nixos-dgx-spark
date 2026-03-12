#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing nim-on-spark ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman
command -v curl
command -v jq

echo "Checking podman..."
PODMAN_HELP=$(podman --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF "run"
echo "OK: podman --help works"

echo "Checking podman version..."
podman --version

echo "Checking curl..."
curl --version | head -1

echo "Checking jq..."
jq --version

echo "Checking podman info (runtime/storage)..."
# Verify podman can report basic system info without requiring root or pulling images
PODMAN_INFO=$(podman info 2>&1 || true)
echo "${PODMAN_INFO}" | grep -qiF "host" \
  || echo "Warning: podman info did not return expected output (may need rootless setup)"
echo "OK: podman info ran"

echo "All tests passed!"
