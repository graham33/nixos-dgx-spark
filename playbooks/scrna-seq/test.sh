#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing scrna-seq ==="

# Verify podman is available
command -v podman

# Check that the shellHook exported the scrna-seq-start helper function
echo "Checking scrna-seq-start function is exported..."
declare -f scrna-seq-start > /dev/null
echo "OK: scrna-seq-start is exported"

echo "All tests passed!"
