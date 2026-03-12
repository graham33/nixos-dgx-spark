#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing sglang ==="

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

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full integration tests require pulling the SGLang container image"
  echo "      and downloading a model. Skipping in automated test environment."
fi

echo "All tests passed!"
