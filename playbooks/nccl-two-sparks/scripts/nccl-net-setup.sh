# Configure the QSFP interconnect on both nodes: addresses, MTU, ARP, firewall,
# then verify and warm each path. Needed once per boot -- none of it persists.
#
# Substitutions: helpers
set -euo pipefail
@helpers@

node1="${1:?Usage: nccl-net-setup <SSH_Node1> <SSH_Node2> [interface] [subnet]}"
node2="${2:?Usage: nccl-net-setup <SSH_Node1> <SSH_Node2> [interface] [subnet]}"
iface="${3:-}"
subnet="${4:-192.168.100}"

# The QSFP MACs come up with carrier but no IPv4 address, and neither OS assigns
# one. Every linked MAC gets one, not just the primary: one physical port is two
# MACs on separate PCIe links and NCCL needs both. The primary (which nccl-run
# uses for NCCL_SOCKET_IFNAME and the MPI bootstrap) goes on $subnet; each
# additional MAC takes the next third octet up.
#
# sed rather than head: head exits after the first line, and the SIGPIPE that
# gives the writing function trips pipefail (exit 141).
primary="$iface"
if [ -z "$primary" ]; then
  primary="$(qsfp_linked | sed -n 1p)"
  if [ -z "$primary" ]; then
    echo "error: no QSFP MAC has carrier -- is the cable connected?" >&2
    exit 1
  fi
  echo "Auto-detected linked QSFP interface: $primary"
fi
iface="$primary"

devs=("$primary")
while read -r p; do
  if [ -n "$p" ] && [ "$p" != "$primary" ]; then
    devs+=("$p")
  fi
done < <(qsfp_linked)

if [ "${#devs[@]}" -gt 1 ]; then
  echo "Also addressing the other linked MAC(s): ${devs[*]:1}"
fi

prefix="${subnet%.*}"
third="${subnet##*.}"
hosts=("$node1" "$node2")

# plan_for <node index> -- print "dev=addr" pairs for that node.
plan_for() {
  local i="$1" j=0 d
  for d in "${devs[@]}"; do
    echo -n "$d=$prefix.$((third + j)).$((11 + i)) "
    j=$((j + 1))
  done
}

# The launcher advertises every local address in its callback URI, management
# address first, and its daemons work through that list in order -- so a dropped
# attempt on the LAN stalls the launch before the interconnect address is ever
# tried. PRRTE 4.1 has no working oob_tcp_if_include to trim the list (the oob
# framework is gone and the parameter is ignored), so instead each node accepts
# anything from the peer, on any of its addresses. That is narrower than
# trusting the LAN interface: exactly one other host, the far end of the cable.
for i in 0 1; do
  host="${hosts[$i]}"
  peer=$((1 - i))
  peer_ssh="${hosts[$peer]}"
  plan="$(plan_for "$i")"
  peer_addrs="$(plan_for "$peer" | tr ' ' '\n' | sed -n 's/.*=//p' | tr '\n' ' ')"

  echo "Configuring $host (sudo required; addressing and firewall)..."
  setup_node "$host" "$plan" "$peer_ssh" "$peer_addrs"
done

# Verify *and warm* every subnet, from both ends. Warming is the important part:
# RoCE will not wait for ARP resolution, it burns its retry budget and the
# connection dies with IBV_WC_RETRY_EXC_ERR. A path whose neighbour entry is
# cold therefore fails the first time NCCL touches it, which is what happens to
# the second MAC if only the first is ever pinged. -c 4 for the same reason: the
# early packets are expected to drop while the entry resolves, and ping reports
# success if any reply arrives.
echo ""
echo "Verifying and warming each link..."
failed=0
j=0
for d in "${devs[@]}"; do
  a1="$prefix.$((third + j)).11"
  a2="$prefix.$((third + j)).12"
  if run_on "$node1" "ping -c 4 -W 2 -I $d $a2 >/dev/null 2>&1" &&
     run_on "$node2" "ping -c 4 -W 2 -I $d $a1 >/dev/null 2>&1"; then
    echo "  OK: $a1 <-> $a2 over $d"
  else
    echo "  FAILED: $a1 <-> $a2 over $d" >&2
    failed=1
  fi
  j=$((j + 1))
done

if [ "$failed" -ne 0 ]; then
  echo "" >&2
  echo "error: at least one interconnect path does not pass traffic." >&2
  echo "NCCL stripes across all of them, so it will fail on the broken one" >&2
  echo "even though the others work. Linked MACs on this node:" >&2
  qsfp_linked | sed 's/^/  /' >&2
  exit 1
fi

echo ""
echo "Now run the benchmark over the fast link:"
echo "  nccl-run $subnet.11 $subnet.12 $iface"
