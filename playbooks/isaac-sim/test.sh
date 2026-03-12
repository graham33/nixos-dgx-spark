#!/usr/bin/env bash
# Full integration tests require a display and Isaac Sim license
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing isaac-sim ==="

# --- Smoke tests (always run) ---

echo "Checking git-lfs (needed for large asset downloads)..."
command -v git-lfs
git lfs install --skip-repo 2>&1 | grep -qF "Git LFS initialized"
echo "OK: git lfs install works"

echo "Checking podman (needed for Isaac Sim container)..."
command -v podman
podman --help 2>&1 | grep -qF "run"
echo "OK: podman supports run subcommand"
podman run --help 2>&1 | grep -qF -- "--device"
echo "OK: podman run supports --device (required for GPU passthrough)"

echo "Checking isaac-sim-container shell function..."
declare -f isaac-sim-container > /dev/null
echo "OK: isaac-sim-container function is defined"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Full integration tests require a display and Isaac Sim license."
  echo "Skipping: launching Isaac Sim container or building from source."
  echo "To run manually:"
  echo "  export DISPLAY=:0 && xhost +local: && isaac-sim-container"
fi

echo "All tests passed!"
