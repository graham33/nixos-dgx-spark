#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing live-vlm-webui ==="

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

echo "All tests passed!"
