{ mkShell
, openssh
, iperf3
, ethtool
, rdma-core
}:

mkShell {
  packages = [
    openssh
    iperf3
    ethtool
    rdma-core
  ];

  shellHook = ''
    echo "=== Connect Two Sparks Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/connect-two-sparks/instructions"
    echo ""
    echo "Note: This playbook requires two DGX Spark units connected via QSFP cable."
    echo ""
    echo "Useful commands:"
    echo "  ibdev2netdev             # Check RDMA/network device status"
    echo "  ethtool <iface>          # Inspect network interface details"
    echo "  iperf3 -s               # Start bandwidth test server"
    echo "  iperf3 -c <other-spark> # Test network throughput"
    echo "  ssh-copy-id user@spark2  # Set up passwordless SSH"
  '';
}
