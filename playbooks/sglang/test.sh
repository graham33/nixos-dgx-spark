#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing sglang ==="

echo "Checking required commands..."
for cmd in podman curl jq; do
  if command -v "$cmd" > /dev/null 2>&1; then
    echo "OK: $cmd is available"
  else
    echo "FAIL: $cmd is not available"
    exit 1
  fi
done

echo "Checking shell functions are defined..."
if declare -f sglang-start > /dev/null 2>&1; then
  echo "OK: function sglang-start is defined"
else
  echo "FAIL: function sglang-start is not defined"
  exit 1
fi

echo "All tests passed!"
