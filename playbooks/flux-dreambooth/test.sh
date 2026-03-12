#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing flux-dreambooth ==="

echo "Checking FLUX_WORKSPACE env var is set..."
if [[ -z "${FLUX_WORKSPACE:-}" ]]; then
  echo "ERROR: FLUX_WORKSPACE is not set (should be exported by shellHook)"
  exit 1
fi
echo "OK: FLUX_WORKSPACE=${FLUX_WORKSPACE}"

echo "Checking podman is available..."
podman --version >/dev/null || { echo "ERROR: podman not found"; exit 1; }
echo "OK: $(podman --version)"

echo "Checking nixglhost is available..."
nixglhost --help >/dev/null 2>&1 || true
command -v nixglhost >/dev/null || { echo "ERROR: nixglhost not found"; exit 1; }
echo "OK: nixglhost found"

echo "Checking shell functions are exported..."
declare -f flux-build-train >/dev/null || { echo "ERROR: flux-build-train not defined"; exit 1; }
declare -f flux-build-comfyui >/dev/null || { echo "ERROR: flux-build-comfyui not defined"; exit 1; }
declare -f flux-download >/dev/null || { echo "ERROR: flux-download not defined"; exit 1; }
declare -f flux-train >/dev/null || { echo "ERROR: flux-train not defined"; exit 1; }
declare -f flux-comfyui >/dev/null || { echo "ERROR: flux-comfyui not defined"; exit 1; }
declare -f flux-pytorch-shell >/dev/null || { echo "ERROR: flux-pytorch-shell not defined"; exit 1; }
declare -f _flux-ensure-workspace >/dev/null || { echo "ERROR: _flux-ensure-workspace not defined"; exit 1; }
echo "OK: all shell functions are exported"

echo "All tests passed!"
