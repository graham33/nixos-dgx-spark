#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing isaac-sim ==="

echo "Checking git-lfs can initialise (needed for large asset downloads)..."
git lfs install --skip-repo 2>&1 | grep -qF "Git LFS initialized"
echo "OK"

echo "Checking podman run supports --device (required for GPU passthrough)..."
podman run --help 2>&1 | grep -qF -- "--device"
echo "OK"

echo "All tests passed!"
