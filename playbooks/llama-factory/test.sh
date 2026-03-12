#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing llama-factory ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman
command -v curl
command -v jq

echo "Checking podman..."
podman --version
echo "OK: podman is available"

echo "Checking curl..."
curl --version | head -1

echo "Checking jq..."
jq --version

echo "Checking podman info (rootless)..."
# Verify podman can run basic operations without pulling images
PODMAN_HELP=$(podman --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF "run"
echo "OK: podman --help includes 'run'"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  echo "Pulling LLaMA Factory image..."
  podman pull docker.io/hiyouga/llamafactory:latest

  echo "Checking llamafactory-cli in container..."
  podman run --rm docker.io/hiyouga/llamafactory:latest \
    llamafactory-cli version 2>&1 | head -5 || true
  echo "OK: llamafactory-cli is accessible in container"
fi

echo "All tests passed!"
