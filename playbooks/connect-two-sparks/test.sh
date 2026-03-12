#!/usr/bin/env bash
# Validate that the Nix devShell provides the tools this playbook needs.
set -euo pipefail

echo "=== Testing connect-two-sparks ==="

for cmd in iperf3 ssh-keygen ssh-copy-id ibv_devices ibstat ethtool; do
  printf "Checking %s... " "$cmd"
  command -v "$cmd" >/dev/null
  echo "OK"
done

echo "All tests passed!"
