{ mkShell
, nixglhost
, openmpi
, cudaPackages
, writeShellScriptBin
}:

let
  nccl-run = writeShellScriptBin "nccl-run" ''
    node1="''${1:?Usage: nccl-run <IP_Node1> <IP_Node2> [interface]}"
    node2="''${2:?Usage: nccl-run <IP_Node1> <IP_Node2> [interface]}"
    iface="''${3:-enp1s0f1np1}"

    export UCX_NET_DEVICES="$iface"
    export NCCL_SOCKET_IFNAME="$iface"
    export OMPI_MCA_btl_tcp_if_include="$iface"

    echo "Running all_gather_perf between $node1 and $node2 on interface $iface..."
    ${openmpi}/bin/mpirun -np 2 -H "$node1":1,"$node2":1 \
      --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
      -x LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
      ${cudaPackages.nccl-tests}/bin/all_gather_perf
  '';

  nccl-run-16g = writeShellScriptBin "nccl-run-16g" ''
    node1="''${1:?Usage: nccl-run-16g <IP_Node1> <IP_Node2> [interface]}"
    node2="''${2:?Usage: nccl-run-16g <IP_Node1> <IP_Node2> [interface]}"
    iface="''${3:-enp1s0f1np1}"

    export UCX_NET_DEVICES="$iface"
    export NCCL_SOCKET_IFNAME="$iface"
    export OMPI_MCA_btl_tcp_if_include="$iface"

    echo "Running all_gather_perf (16G buffer) between $node1 and $node2 on interface $iface..."
    ${openmpi}/bin/mpirun -np 2 -H "$node1":1,"$node2":1 \
      --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
      -x LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
      ${cudaPackages.nccl-tests}/bin/all_gather_perf -b 16G -e 16G -f 2
  '';
in

mkShell {
  packages = [
    nixglhost
    openmpi
    cudaPackages.nccl
    cudaPackages.nccl-tests
    nccl-run
    nccl-run-16g
  ];

  shellHook = ''
    echo "=== NCCL for Two Sparks Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nccl/instructions"
    echo ""
    echo "Note: This playbook requires two DGX Spark units."
    echo ""
    echo "Run all_gather_perf across two nodes:"
    echo "  nccl-run <IP_Node1> <IP_Node2> [interface]"
    echo ""
  '';
}
