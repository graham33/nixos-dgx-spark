#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing cuda-x-data-science ==="

echo "Checking podman is available..."
command -v podman > /dev/null
echo "OK: podman is available"

echo "Checking nixglhost is available..."
command -v nixglhost > /dev/null
echo "OK: nixglhost is available"

echo "All tests passed!"
