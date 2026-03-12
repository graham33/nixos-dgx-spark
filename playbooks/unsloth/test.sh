#!/usr/bin/env bash
set -euo pipefail

FULL=0
for arg in "$@"; do
  [[ "$arg" == "--full" ]] && FULL=1
done

echo "=== Testing unsloth ==="

# Podman is the only tool this playbook needs
command -v podman

# The shellHook exports unsloth-start; verify it is available
if ! declare -f unsloth-start > /dev/null 2>&1; then
  echo "ERROR: unsloth-start function not found (shellHook not sourced?)" >&2
  exit 1
fi
echo "OK: unsloth-start function defined"

# HF_HOME should default gracefully (not required to be set)
HF_CACHE="${HF_HOME:-$HOME/.cache/huggingface}"
echo "OK: HuggingFace cache path: ${HF_CACHE}"

if [[ "$FULL" -eq 1 ]]; then
  echo "--- Full tests ---"
  echo "Pulling container image (this may take a while)..."
  podman pull nvcr.io/nvidia/pytorch:25.11-py3
  echo "OK: container image pulled"
fi

echo "All tests passed!"
