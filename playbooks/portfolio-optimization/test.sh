#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing portfolio-optimization ==="

echo "Checking binaries..."
command -v podman

echo "Checking shell helper functions..."
declare -f portfolio-start > /dev/null
echo "OK: portfolio-start function is defined"

echo "All tests passed!"
