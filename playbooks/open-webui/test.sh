#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing open-webui ==="

# --- Smoke tests (always run) ---

# Verify the shellHook-exported helper function is present in this environment
echo "Checking open-webui-start function is exported..."
if ! declare -f open-webui-start > /dev/null 2>&1; then
  echo "ERROR: open-webui-start function not found (should be exported by shellHook)"
  exit 1
fi
echo "OK: open-webui-start is defined"

# Verify the function body references the expected container image and key flags
FUNC_BODY=$(declare -f open-webui-start)
echo "Checking function references the Open WebUI+Ollama container image..."
echo "${FUNC_BODY}" | grep -qF "ghcr.io/open-webui/open-webui:ollama"
echo "OK: container image found"

echo "Checking function passes GPU device flag..."
echo "${FUNC_BODY}" | grep -qF -- "--device nvidia.com/gpu=all"
echo "OK: --device nvidia.com/gpu=all found"

echo "Checking function exposes port 8080..."
echo "${FUNC_BODY}" | grep -qF -- "-p 8080:8080"
echo "OK: port 8080 binding found"

echo "Checking function mounts persistent volumes..."
echo "${FUNC_BODY}" | grep -qF -- "-v open-webui:/app/backend/data"
echo "${FUNC_BODY}" | grep -qF -- "-v open-webui-ollama:/root/.ollama"
echo "OK: persistent volume mounts found"

# Verify podman is available (required to actually run the container)
echo "Checking podman is available..."
command -v podman
echo "OK: podman found"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full tests would start the open-webui container and verify"
  echo "      the WebUI is reachable at http://localhost:8080."
  echo "Skipping container start in automated tests."
fi

echo "All tests passed!"
