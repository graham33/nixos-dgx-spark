#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing live-vlm-webui ==="

# --- Smoke tests (always run) ---

# Verify the shellHook-exported helper functions are present in this environment
for fn in live-vlm-start live-vlm-pull-model live-vlm-models live-vlm-stop; do
  echo "Checking ${fn} function is exported..."
  if ! declare -f "${fn}" > /dev/null 2>&1; then
    echo "ERROR: ${fn} function not found (should be exported by shellHook)"
    exit 1
  fi
  echo "OK: ${fn} is defined"
done

# Verify live-vlm-start references the expected container images and key flags
FUNC_BODY=$(declare -f live-vlm-start)

echo "Checking live-vlm-start references the Live VLM WebUI container image..."
echo "${FUNC_BODY}" | grep -qF "ghcr.io/nvidia-ai-iot/live-vlm-webui:latest"
echo "OK: live-vlm-webui container image found"

echo "Checking live-vlm-start references the Ollama container image..."
echo "${FUNC_BODY}" | grep -qF "docker.io/ollama/ollama:latest"
echo "OK: ollama container image found"

echo "Checking live-vlm-start passes GPU device flag to Ollama..."
echo "${FUNC_BODY}" | grep -qF -- "--device nvidia.com/gpu=all"
echo "OK: --device nvidia.com/gpu=all found"

echo "Checking live-vlm-start uses host networking..."
echo "${FUNC_BODY}" | grep -qF -- "--network host"
echo "OK: --network host found"

echo "Checking live-vlm-start references WebUI port 8090..."
echo "${FUNC_BODY}" | grep -qF "8090"
echo "OK: port 8090 found"

echo "Checking live-vlm-start references Ollama port 11434..."
echo "${FUNC_BODY}" | grep -qF "11434"
echo "OK: port 11434 found"

# Verify podman is available (required to actually run the containers)
echo "Checking podman is available..."
command -v podman
echo "OK: podman found"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."
  echo "NOTE: Full tests would start the Ollama and Live VLM WebUI containers"
  echo "      and verify the WebUI is reachable at https://localhost:8090."
  echo "Skipping container start in automated tests."
fi

echo "All tests passed!"
