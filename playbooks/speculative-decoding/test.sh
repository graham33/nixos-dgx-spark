#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing speculative-decoding ==="

echo "Checking required commands..."
for cmd in podman curl jq nixglhost; do
  if command -v "$cmd" > /dev/null 2>&1; then
    echo "OK: $cmd is available"
  else
    echo "FAIL: $cmd is not available"
    exit 1
  fi
done

echo "All tests passed!"
