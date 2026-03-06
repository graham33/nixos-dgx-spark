{ mkShell
, openmpi
, git
, gnumake
, cudaPackages
}:

mkShell {
  packages = [
    openmpi
    git
    gnumake
    cudaPackages.cuda_nvcc
  ];

  shellHook = ''
    echo "=== NCCL for Two Sparks Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nccl/instructions"
    echo ""
    echo "Note: This playbook requires two DGX Spark units."
    echo ""
    echo "Step 1: Build NCCL with Blackwell support"
    echo "  nccl-build"
    echo ""
    echo "Step 2: Build NCCL test suite"
    echo "  nccl-build-tests"
    echo ""
    echo "Step 3: Run all_gather_perf across two nodes"
    echo "  nccl-run <IP_Node1> <IP_Node2> [interface]"
    echo ""

    export CUDA_HOME="${cudaPackages.cuda_nvcc}"
    export NCCL_HOME="$HOME/nccl/build/"
    export LD_LIBRARY_PATH="$NCCL_HOME/lib:$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

    nccl-build() {
      echo "Cloning and building NCCL v2.28.9-1 with Blackwell support..."
      ${git}/bin/git clone -b v2.28.9-1 https://github.com/NVIDIA/nccl.git ~/nccl/
      cd ~/nccl/
      ${gnumake}/bin/make -j src.build NVCC_GENCODE="-gencode=arch=compute_121,code=sm_121"
      cd -
      echo "NCCL built. Library at $NCCL_HOME/lib"
    }

    nccl-build-tests() {
      echo "Cloning and building NCCL tests..."
      ${git}/bin/git clone https://github.com/NVIDIA/nccl-tests.git ~/nccl-tests/
      cd ~/nccl-tests/
      ${gnumake}/bin/make MPI=1
      cd -
      echo "NCCL tests built at ~/nccl-tests/build/"
    }

    nccl-run() {
      local node1="''${1:?Usage: nccl-run <IP_Node1> <IP_Node2> [interface]}"
      local node2="''${2:?Usage: nccl-run <IP_Node1> <IP_Node2> [interface]}"
      local iface="''${3:-enp1s0f1np1}"

      export UCX_NET_DEVICES="$iface"
      export NCCL_SOCKET_IFNAME="$iface"
      export OMPI_MCA_btl_tcp_if_include="$iface"

      echo "Running all_gather_perf between $node1 and $node2 on interface $iface..."
      ${openmpi}/bin/mpirun -np 2 -H "$node1":1,"$node2":1 \
        --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
        -x LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
        "$HOME/nccl-tests/build/all_gather_perf"
    }

    nccl-run-16g() {
      local node1="''${1:?Usage: nccl-run-16g <IP_Node1> <IP_Node2> [interface]}"
      local node2="''${2:?Usage: nccl-run-16g <IP_Node1> <IP_Node2> [interface]}"
      local iface="''${3:-enp1s0f1np1}"

      export UCX_NET_DEVICES="$iface"
      export NCCL_SOCKET_IFNAME="$iface"
      export OMPI_MCA_btl_tcp_if_include="$iface"

      echo "Running all_gather_perf (16G buffer) between $node1 and $node2 on interface $iface..."
      ${openmpi}/bin/mpirun -np 2 -H "$node1":1,"$node2":1 \
        --mca plm_rsh_agent "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
        -x LD_LIBRARY_PATH="$LD_LIBRARY_PATH" \
        "$HOME/nccl-tests/build/all_gather_perf" -b 16G -e 16G -f 2
    }

    export -f nccl-build
    export -f nccl-build-tests
    export -f nccl-run
    export -f nccl-run-16g
  '';
}
