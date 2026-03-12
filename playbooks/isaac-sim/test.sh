#!/usr/bin/env bash
# Full integration tests require a display and Isaac Sim license
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing isaac-sim ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v git
command -v git-lfs
command -v podman

echo "Checking git..."
git --version

echo "Checking git-lfs..."
git-lfs --version

echo "Checking podman..."
PODMAN_HELP=$(podman --help 2>&1 || true)
echo "${PODMAN_HELP}" | grep -qF "run"
echo "OK: podman --help works"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Full integration tests require a display and Isaac Sim license."
  echo "Skipping: launching Isaac Sim container or building from source."
  echo "To run manually:"
  echo "  export DISPLAY=:0 && xhost +local: && isaac-sim-container"
fi

echo "All tests passed!"
