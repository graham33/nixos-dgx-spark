# Shared helpers, inlined into each script at @helpers@. Some are also shipped
# to the remote node verbatim, so they must work on both NixOS and DGX OS --
# hence no ibdev2netdev, which is not on PATH in the devshell.
#
# Substitutions: sshOpts mtu

# QSFP/ConnectX ports on the Spark are named enp1s0f0np0, enP2p1s0f1np1 and so
# on. Print those that have carrier, i.e. a cable with a live peer.
qsfp_linked() {
  local f n
  for f in /sys/class/net/*np[0-9]; do
    [ -e "$f/carrier" ] || continue
    n="${f##*/}"
    if [ "$(cat "$f/carrier" 2>/dev/null || echo 0)" = 1 ]; then
      echo "$n"
    fi
  done
}

# Of those, the ones that also carry a global IPv4 address, i.e. usable.
qsfp_ready() {
  local n
  for n in $(qsfp_linked); do
    if ip -o -4 addr show dev "$n" scope global 2>/dev/null |
         grep inet >/dev/null; then
      echo "$n"
    fi
  done
}

# No grep -q anywhere in here: it closes the pipe on the first match, and the
# resulting SIGPIPE upstream trips pipefail -- which would turn a match into a
# non-zero status and make this node look remote.
is_local_addr() {
  ip -o addr show 2>/dev/null | awk '{ print $4 }' | cut -d/ -f1 |
    grep -xF "$1" >/dev/null
}

# Capture a snippet's output from a node. No -t, unlike run_on, so nothing
# tty-related contaminates the value.
capture_on() {
  local host="$1"; shift
  if is_local_addr "$host"; then
    bash -c "$*"
  else
    ssh @sshOpts@ "$host" "$*" 2>/dev/null | tr -d '\r'
  fi
}

# Run a shell snippet on a node, locally if the address is ours. -t so that a
# sudo password prompt works.
run_on() {
  local host="$1"; shift
  if is_local_addr "$host"; then
    bash -c "$*"
  else
    ssh -t @sshOpts@ "$host" "$*"
  fi
}

# Interconnect addresses do not survive a reboot, so the likeliest reason an
# address is unusable is that nccl-net-setup has not run since the last boot.
# Say so, rather than letting an ssh to an unconfigured address stall.
require_reachable() {
  local host="$1"
  is_local_addr "$host" && return 0
  ping -c 1 -W 2 "$host" >/dev/null 2>&1 && return 0
  # ICMP might be filtered even where ssh works, so try a TCP connect too.
  timeout 3 bash -c "echo > /dev/tcp/$host/22" 2>/dev/null && return 0
  echo "error: $host is neither one of this node's addresses nor reachable." >&2
  echo "  Interconnect addresses are lost on reboot -- re-run:" >&2
  echo "    nccl-net-setup <SSH_Node1> <SSH_Node2>" >&2
  exit 1
}

# RDMA pins the memory it registers, so a low memlock ceiling breaks multi-node
# runs. NixOS defaults to 8 MB; DGX OS sets nearly all of RAM, so a mixed pair
# fails on the NixOS side only.
#
# An error rather than a warning: with an IB device present NCCL does not fall
# back to sockets, it dies with "ibv_reg_mr_iova2 failed with error Cannot
# allocate memory" and the peer then reports a closed connection -- so the rank
# that actually failed is not the one that looks guilty. As a warning it just
# scrolled past unread. NCCL_RUN_IGNORE_MEMLOCK=1 proceeds anyway, e.g. to test
# the socket transport deliberately.
require_memlock() {
  local host="$1" lim
  lim="$(capture_on "$host" 'ulimit -Hl' || true)"
  case "$lim" in
    unlimited | "") return 0 ;;
  esac
  case "$lim" in
    *[!0-9]*) return 0 ;;
  esac
  [ "$lim" -ge 1048576 ] && return 0

  echo "error: $host has a max locked memory limit of only $lim kB." >&2
  echo "  RDMA buffer registration will fail and the run will abort." >&2
  echo "  For this shell:" >&2
  echo "    sudo prlimit --memlock=unlimited --pid \$\$" >&2
  echo "  Permanently on NixOS: the dgx-spark module sets this via" >&2
  echo "  security.pam.loginLimits -- rebuild, then log in again." >&2
  if [ -n "${NCCL_RUN_IGNORE_MEMLOCK:-}" ]; then
    echo "  (continuing anyway: NCCL_RUN_IGNORE_MEMLOCK is set)" >&2
    return 0
  fi
  exit 1
}

# setup_node <host> <plan> <peer_ssh> <peer_addrs>
#
# plan is a space-separated list of dev=address pairs; peer_addrs a
# space-separated list of the other node's addresses.
#
# Everything needing root on one node goes in a single invocation, so it costs
# one sudo password prompt per node rather than one per command.
setup_node() {
  local host="$1" plan="$2" peer_ssh="$3" peer_addrs="$4"
  run_on "$host" "
    set -e

    # One address per linked MAC, each on its own /24, plus jumbo frames.
    #
    # Addressing every MAC matters more than it looks: a Spark's single physical
    # QSFP port presents two 100G MACs, one per PCIe x4 link, and NCCL needs
    # both to reach 200 Gbps. RoCEv2 derives its GIDs from the interface's IP
    # addresses, so an unaddressed MAC has only link-local GIDs and no IPv4
    # RoCEv2 entry -- check /sys/class/infiniband/<dev>/ports/1/gids.
    #
    # MTU: the RoCE path MTU is capped by the netdev MTU, and at the default
    # 1500 the RDMA MTU is 1024 rather than 4096. Confirm with ibv_devinfo's
    # active_mtu. Jumbo frames are safe on a direct cable with no switch.
    for pair in $plan; do
      d=\"\${pair%%=*}\"
      a=\"\${pair#*=}\"
      sudo ip link set \"\$d\" up
      sudo ip addr replace \"\$a/24\" dev \"\$d\"
      sudo ip link set \"\$d\" mtu @mtu@

      # Both MACs sit on one physical port, hence one L2 segment, so default ARP
      # answers and announces for either interface from whichever it likes --
      # 'ARP flux'. The neighbour table then holds the peer on both interfaces
      # and which path works is luck. arp_ignore=1 answers only for the address
      # on the receiving interface; arp_announce=2 always sources from that
      # interface's own address.
      sudo sysctl -qw \"net.ipv4.conf.\$d.arp_ignore=1\"
      sudo sysctl -qw \"net.ipv4.conf.\$d.arp_announce=2\"

      echo \"  \$d: \$a/24, mtu @mtu@, arp_ignore/announce set\"
    done

    # GPUDirect RDMA lets the NIC read GPU memory directly instead of NCCL
    # staging through host memory. The nvidia_peermem route needs the
    # peer-memory API that DOCA-OFED adds to ib_core; without that symbol it
    # cannot load at all, so only try when it is there.
    if grep -l ib_register_peer_memory_client /proc/kallsyms >/dev/null 2>&1; then
      if sudo modprobe nvidia_peermem 2>/dev/null; then
        echo '  nvidia_peermem loaded (GPUDirect RDMA)'
      else
        echo '  note: nvidia_peermem present but would not load' >&2
      fi
    else
      echo '  GPUDirect RDMA: no peer-memory API in this kernel, DMA-BUF path only'
    fi

    # Both nodes filter inbound traffic, with different tooling: NixOS has its
    # nixos-fw chain, DGX OS runs ufw, active by default. Finding neither is an
    # error, not a shrug -- a failed sudo looks exactly like an absent firewall
    # from here, and claiming there was nothing to do sends you chasing the
    # wrong thing.
    if sudo iptables -L nixos-fw -n >/dev/null 2>&1; then
      for pair in $plan; do
        m=\"-i \${pair%%=*}\"
        sudo iptables -C nixos-fw \$m -j nixos-fw-accept 2>/dev/null ||
          sudo iptables -I nixos-fw 1 \$m -j nixos-fw-accept
        echo \"  firewall (nixos-fw): accept \$m\"
      done
      for src in $peer_ssh $peer_addrs; do
        sudo iptables -C nixos-fw -s \"\$src\" -j nixos-fw-accept 2>/dev/null ||
          sudo iptables -I nixos-fw 1 -s \"\$src\" -j nixos-fw-accept
        echo \"  firewall (nixos-fw): accept from \$src\"
      done
    elif sudo ufw status >/dev/null 2>&1; then
      for pair in $plan; do
        sudo ufw allow in on \"\${pair%%=*}\" >/dev/null
        echo \"  firewall (ufw): accept in on \${pair%%=*}\"
      done
      for src in $peer_ssh $peer_addrs; do
        sudo ufw allow from \"\$src\" >/dev/null
        echo \"  firewall (ufw): accept from \$src\"
      done
    else
      echo 'error: found neither the nixos-fw chain nor a working ufw on $host.' >&2
      echo 'If sudo just failed, fix that and re-run -- inbound traffic from' >&2
      echo 'the peer must be allowed or the MPI launch will fail.' >&2
      exit 1
    fi"
}
