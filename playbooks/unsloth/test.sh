#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing unsloth ==="

# Validate packages provided by the Nix devShell
command -v podman
command -v nixglhost

echo "All tests passed!"
