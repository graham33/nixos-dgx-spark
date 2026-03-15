#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing live-vlm-webui ==="

# Verify the devShell provides the tools this playbook needs
for cmd in podman curl jq; do
  echo "Checking ${cmd} is available..."
  command -v "${cmd}"
  echo "OK: ${cmd} found"
done

echo "All tests passed!"
