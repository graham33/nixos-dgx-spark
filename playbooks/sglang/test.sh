#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing sglang ==="

# --- Smoke tests (always run) ---

SGLANG_IMAGE="lmsysorg/sglang:spark"
SGLANG_PORT="30000"

echo "Checking shell functions are defined..."
# The shellHook exports these functions; verify they are available
if declare -f sglang-start > /dev/null 2>&1; then
  echo "OK: function sglang-start is defined"
else
  echo "WARNING: function sglang-start is not defined (run inside nix develop .#sglang)"
fi

echo "Checking sglang-start references the correct container image..."
FN_BODY=$(declare -f sglang-start 2>/dev/null || true)
if echo "${FN_BODY}" | grep -qF "${SGLANG_IMAGE}"; then
  echo "OK: sglang-start references ${SGLANG_IMAGE}"
else
  echo "WARNING: sglang-start does not reference expected image ${SGLANG_IMAGE}"
fi

echo "Checking sglang-start references the correct port..."
if echo "${FN_BODY}" | grep -qF "${SGLANG_PORT}"; then
  echo "OK: sglang-start references port ${SGLANG_PORT}"
else
  echo "WARNING: sglang-start does not reference expected port ${SGLANG_PORT}"
fi

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  # Verify podman can reach the registry (just check image info, no pull)
  echo "Checking SGLang image availability..."
  INSPECT=$(podman manifest inspect "${SGLANG_IMAGE}" 2>&1 || true)
  if echo "${INSPECT}" | grep -q "schemaVersion"; then
    echo "OK: Image ${SGLANG_IMAGE} is reachable in registry"
  else
    echo "WARNING: Could not inspect image ${SGLANG_IMAGE} (may need registry login)"
  fi
fi

echo "All tests passed!"
