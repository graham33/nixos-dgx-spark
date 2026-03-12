#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing pytorch-finetune ==="

echo "Checking podman available..."
command -v podman
echo "OK: podman available"

echo "Checking pytorch-finetune shell helper exported..."
declare -f pytorch-finetune > /dev/null
echo "OK: pytorch-finetune function is exported"

echo "All tests passed!"
