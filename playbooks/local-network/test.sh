#!/usr/bin/env bash
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing local-network ==="

# --- Smoke tests (always run) ---

echo "Checking nmap..."
nmap --version | head -1
echo "OK: nmap is available"

echo "Checking avahi-browse supports mDNS browsing flags..."
AVAHI_HELP=$(avahi-browse --help 2>&1 || true)
echo "${AVAHI_HELP}" | grep -qF -- "--all"
echo "${AVAHI_HELP}" | grep -qF -- "--resolve"
echo "${AVAHI_HELP}" | grep -qF -- "--terminate"
echo "OK: avahi-browse supports mDNS browsing flags"

echo "Checking ssh supports port forwarding (-L)..."
SSH_HELP=$(ssh 2>&1 || true)
echo "${SSH_HELP}" | grep -qF -- "-L"
echo "OK: ssh supports port forwarding"

# --- Full tests (only with --full) ---
if $FULL; then
  echo "Running full tests..."

  echo "Checking nmap local scan (loopback)..."
  nmap -sn 127.0.0.1
  echo "OK: nmap scan completed"
fi

echo "All tests passed!"
