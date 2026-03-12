#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing open-webui ==="

# Verify the shellHook-exported helper function is present in this environment
echo "Checking open-webui-start function is exported..."
if ! declare -f open-webui-start > /dev/null 2>&1; then
  echo "ERROR: open-webui-start function not found (should be exported by shellHook)"
  exit 1
fi
echo "OK: open-webui-start is defined"

# Verify podman is available (required to actually run the container)
echo "Checking podman is available..."
command -v podman
echo "OK: podman found"

echo "All tests passed!"
