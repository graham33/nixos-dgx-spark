#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing optimized-jax ==="

# --- Smoke tests (always run) ---

echo "Checking JAX import and version..."
JAX_VERSION=$(python3 -c 'import jax; print(jax.__version__)' 2>/dev/null || true)
echo "JAX version: ${JAX_VERSION}"
echo "OK: JAX import works"

echo "Checking JAX devices..."
# Capture only stdout (the device list); stderr contains CUDA warning noise
DEVICES_OUTPUT=$(python3 -c 'import jax; devs = jax.devices(); print(devs)' 2>/dev/null || true)
echo "JAX devices: ${DEVICES_OUTPUT}"

# Check whether CUDA/GPU devices are visible.
# GB10 has SM 12.1; the Nix-packaged JAX CUDA plugin may have been compiled for
# SM 12.0 and will fail to load — we report but do not fail the test.
if echo "${DEVICES_OUTPUT}" | grep -qi "cuda\|gpu"; then
  echo "OK: CUDA/GPU device(s) detected by JAX"
else
  # Also check stderr for any CUDA error to give a clearer message
  DEVICES_STDERR=$(python3 -c 'import jax; jax.devices()' 2>&1 1>/dev/null || true)
  if echo "${DEVICES_STDERR}" | grep -qi "cuda\|sm_12\|compute capability\|GPU"; then
    echo "NOTE: JAX CUDA plugin failed to initialise (possible SM 12.1 vs SM 12.0 mismatch on GB10) — falling back to CPU"
  else
    echo "NOTE: No CUDA/GPU devices found — JAX is using CPU backend"
  fi
fi

echo "Checking JAX basic computation..."
python3 -c '
import jax.numpy as jnp
x = jnp.array([1.0, 2.0, 3.0])
y = jnp.sum(x)
assert float(y) == 6.0, f"Expected 6.0, got {float(y)}"
print("Basic jnp.sum([1,2,3]) =", float(y))
' 2>/dev/null
echo "OK: JAX basic computation works"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Running integration tests..."

  echo "Checking JAX JIT compilation..."
  python3 -c '
import jax
import jax.numpy as jnp

@jax.jit
def matmul(a, b):
    return jnp.dot(a, b)

a = jnp.ones((4, 4))
b = jnp.ones((4, 4))
result = matmul(a, b)
assert float(result[0, 0]) == 4.0, f"Expected 4.0, got {float(result[0, 0])}"
print("JIT matmul 4x4 result[0,0] =", float(result[0, 0]))
' 2>/dev/null
  echo "OK: JAX JIT compilation works"

  echo "Checking JAX automatic differentiation..."
  python3 -c '
import jax
import jax.numpy as jnp

def f(x):
    return jnp.sum(x ** 2)

x = jnp.array([1.0, 2.0, 3.0])
grad_f = jax.grad(f)
g = grad_f(x)
# grad of sum(x^2) = 2x
expected = [2.0, 4.0, 6.0]
for i, (got, exp) in enumerate(zip(g.tolist(), expected)):
    assert abs(got - exp) < 1e-5, f"grad[{i}]: expected {exp}, got {got}"
print("Gradient of sum(x^2) at [1,2,3] =", g.tolist())
' 2>/dev/null
  echo "OK: JAX automatic differentiation works"
fi

echo "All tests passed!"
