#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing local-network ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v ssh
command -v nmap
command -v avahi-browse

echo "Checking ssh..."
SSH_HELP=$(ssh 2>&1 || true)
echo "${SSH_HELP}" | grep -qF "usage:"
echo "OK: ssh is functional"

echo "Checking nmap..."
nmap --version | head -1
echo "OK: nmap --version works"

echo "Checking avahi-browse..."
AVAHI_HELP=$(avahi-browse --help 2>&1 || true)
echo "${AVAHI_HELP}" | grep -qF -- "--all"
echo "OK: avahi-browse --help works"

# --- Full tests (only with --full) ---
if $FULL; then
  echo "Running full tests..."

  echo "Checking nmap local scan (loopback)..."
  nmap -sn 127.0.0.1
  echo "OK: nmap scan completed"
fi

echo "All tests passed!"
