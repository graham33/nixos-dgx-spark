#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing nemo-finetune ==="

echo "Checking podman is available..."
podman --version > /dev/null
echo "OK: podman is available"

echo "Checking nixglhost is available..."
nixglhost --help > /dev/null
echo "OK: nixglhost is available"

echo "All tests passed!"
