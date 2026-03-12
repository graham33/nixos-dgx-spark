#!/usr/bin/env bash
set -euo pipefail

FULL=0
for arg in "$@"; do
  [ "$arg" = "--full" ] && FULL=1
done

echo "=== Testing nim-on-spark ==="

# Verify nim-start shell function is exported from shellHook
echo "Checking nim-start function is defined and exported..."
declare -f nim-start > /dev/null
echo "OK: nim-start function is defined"

# Verify nim-start references the correct NIM container image
echo "Checking nim-start references correct NIM container image..."
declare -f nim-start | grep -qF "nvcr.io/nim/meta/llama-3.1-8b-instruct-dgx-spark:latest"
echo "OK: nim-start references nvcr.io/nim/meta/llama-3.1-8b-instruct-dgx-spark:latest"

# Verify nim-start mounts NIM_CACHE and NIM_WORKSPACE
echo "Checking nim-start mounts NIM_CACHE..."
declare -f nim-start | grep -qF "NIM_CACHE"
echo "OK: nim-start references NIM_CACHE"

echo "Checking nim-start mounts NIM_WORKSPACE..."
declare -f nim-start | grep -qF "NIM_WORKSPACE"
echo "OK: nim-start references NIM_WORKSPACE"

# Verify nim-start passes NGC_API_KEY to the container
echo "Checking nim-start passes NGC_API_KEY..."
declare -f nim-start | grep -qF "NGC_API_KEY"
echo "OK: nim-start references NGC_API_KEY"

# Verify nim-start uses GPU passthrough
echo "Checking nim-start uses GPU device passthrough..."
declare -f nim-start | grep -qF "nvidia.com/gpu=all"
echo "OK: nim-start passes nvidia.com/gpu=all"

# Verify nim-start exposes the OpenAI-compatible endpoint on host network
echo "Checking nim-start uses host networking (for localhost:8000/v1)..."
declare -f nim-start | grep -qF "network host"
echo "OK: nim-start uses --network host"

if [ "$FULL" -eq 1 ]; then
  echo "--- Full tests ---"
  echo "Checking NGC_API_KEY is set..."
  if [ -z "${NGC_API_KEY:-}" ]; then
    echo "SKIP: NGC_API_KEY is not set (required for full NIM tests)"
  else
    echo "OK: NGC_API_KEY is set"
  fi
fi

echo "All tests passed!"
