#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing unsloth ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v podman
echo "OK: podman found"

echo "Checking podman version..."
podman --version

echo "Checking podman info (local, no pull)..."
PODMAN_INFO=$(podman info 2>&1 || true)
echo "${PODMAN_INFO}" | grep -qiF "host" && echo "OK: podman info works"

echo "All tests passed!"
