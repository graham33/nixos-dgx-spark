#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing nim-on-spark ==="

# Verify tools provided by the devShell
echo "Checking podman is available..."
command -v podman > /dev/null
echo "OK: podman"

echo "Checking curl is available..."
command -v curl > /dev/null
echo "OK: curl"

echo "Checking jq is available..."
command -v jq > /dev/null
echo "OK: jq"

# Verify nim-start shell function is exported from shellHook
echo "Checking nim-start function is defined..."
declare -f nim-start > /dev/null
echo "OK: nim-start"

echo "All tests passed!"
