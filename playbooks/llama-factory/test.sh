#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing llama-factory ==="

echo "Checking podman is available..."
podman --version > /dev/null
echo "OK: podman is available"

echo "Checking nixglhost is available..."
nixglhost --help > /dev/null 2>&1 || true
command -v nixglhost > /dev/null
echo "OK: nixglhost is available"

echo "All tests passed!"
