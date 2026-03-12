#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing trt-llm ==="

echo "Checking required commands..."
for cmd in podman curl jq; do
  command -v "$cmd" > /dev/null
  echo "OK: $cmd"
done

echo "Checking shell functions are defined..."
for fn in trt-llm-validate trt-llm-quickstart trt-llm-serve trt-llm-test; do
  declare -f "$fn" > /dev/null
  echo "OK: $fn"
done

echo "All tests passed!"
