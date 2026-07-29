{ lib
, mkShell
, nixglhost
, openmpi
, cudaPackages
, rdma-core
, perftest
, writeShellScriptBin
}:

let
  # nixpkgs builds nccl-tests without MPI (no MPI=1 in makeFlags, no MPI in
  # buildInputs), which quietly makes every rank a world of one: a two-node run
  # then prints two separate single-rank results with 0 bus bandwidth instead
  # of one 2-rank result. Rebuild it with MPI so the ranks share a job.
  #
  # NVCC_GENCODE is narrowed to the GB10's sm_121 at the same time -- the
  # default spans every capability from sm_75 up, which is a long compile for
  # architectures no Spark has.
  nccl-tests-mpi = cudaPackages.nccl-tests.overrideAttrs (old: {
    pname = "nccl-tests-mpi";
    buildInputs = (old.buildInputs or [ ]) ++ [ openmpi ];
    makeFlags = (old.makeFlags or [ ]) ++ [
      "MPI=1"
      "MPI_HOME=${openmpi}"
      "NVCC_GENCODE=-gencode=arch=compute_121,code=sm_121"
    ];
  });

  # Store paths that must exist on *both* nodes: mpirun spawns `prted` from the
  # openmpi/prrte closure over ssh, and each rank execs nccl-tests via nixglhost.
  #
  # nccl-ssh belongs here too, even though only the launcher ever runs it: the
  # plm_ssh_agent path is forwarded to the remote daemon, which resolves it on
  # startup and, if it is missing, segfaults right after complaining -- which
  # the launcher then reports only as "PRTE has lost communication".
  remoteClosure = [
    nccl-ssh
    nixglhost
    openmpi
    perftest
    rdma-core
    cudaPackages.nccl
    nccl-tests-mpi
  ];

  # ConnectTimeout matters more than it looks: without it, ssh to an address
  # that is not currently configured sits in TCP connect for two minutes, and
  # since some of these calls happen before any output is printed, that looks
  # like the script hanging for no reason.
  sshOpts = "-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5";

  # Jumbo frames on the interconnect, so RoCE negotiates a 4096-byte path MTU
  # instead of 1024.
  mtu = 9000;

  # Maps a netdev to its RDMA device, as one line so it can be shipped to the
  # far node inside a command string. The two Sparks name the same hardware
  # differently -- mlx5_0 on NixOS, rocep1s0f0 on DGX OS -- so the name has to
  # be resolved on each node rather than assumed or passed across.
  ibdevForFn = "ibdev_for() { local want=\"$1\" d n; "
    + "for d in /sys/class/infiniband/*; do "
    + "for n in \"$d\"/ports/1/gid_attrs/ndevs/*; do "
    + "if [ \"$(cat \"$n\" 2>/dev/null)\" = \"$want\" ]; then "
    + "basename \"$d\"; return 0; fi; done; done; return 1; }";

  # prrte mangles a multi-word plm_rsh_agent value (it re-serialises the mca
  # param when forwarding to prted, splitting the option string), so hand it a
  # single-token wrapper instead of "ssh -o ...".
  nccl-ssh = writeShellScriptBin "nccl-ssh" ''
    exec ssh ${sshOpts} "$@"
  '';

  # The scripts live in ./scripts as plain shell -- they are long enough that
  # inlining them here buried the logic under nix string escaping. Placeholders
  # are @name@ rather than ${name} so the files stay valid shell, readable and
  # shellcheck-able on their own.
  substitute = vars: file:
    builtins.replaceStrings
      (map (k: "@${k}@") (builtins.attrNames vars))
      (map toString (builtins.attrValues vars))
      (builtins.readFile file);

  helpers = substitute { inherit sshOpts mtu; } ./scripts/helpers.sh;

  mkScript = name: vars: file:
    writeShellScriptBin name (substitute ({ inherit helpers; } // vars) file);

  nccl-net-setup = mkScript "nccl-net-setup" { } ./scripts/nccl-net-setup.sh;

  nccl-rdma-check = mkScript "nccl-rdma-check"
    {
      inherit ibdevForFn sshOpts;
      perftest = "${perftest}";
    } ./scripts/nccl-rdma-check.sh;

  mkNcclRun = { name, description, testArgs ? "" }:
    mkScript name
      {
        inherit name description testArgs sshOpts;
        openmpi = "${openmpi}";
        ncclSsh = "${nccl-ssh}";
        nixglhost = "${nixglhost}";
        rdmaCore = "${rdma-core}";
        ncclTests = "${nccl-tests-mpi}";
        remoteClosure = lib.concatStringsSep " " (map toString remoteClosure);
      } ./scripts/nccl-run.sh;

  nccl-run = mkNcclRun {
    name = "nccl-run";
    description = "all_gather_perf";
  };

  nccl-run-16g = mkNcclRun {
    name = "nccl-run-16g";
    description = "all_gather_perf (16G buffer)";
    testArgs = "-b 16G -e 16G -f 2";
  };
in

mkShell {
  packages = [
    nixglhost
    openmpi
    perftest
    rdma-core
    cudaPackages.nccl
    nccl-tests-mpi
    nccl-net-setup
    nccl-rdma-check
    nccl-run
    nccl-run-16g
  ];

  shellHook = ''
    echo "=== NCCL for Two Sparks Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nccl/instructions"
    echo ""
    echo "Note: This playbook requires two DGX Spark units."
    echo ""
    echo "One-off: address the QSFP link (does not survive a reboot):"
    echo "  nccl-net-setup <SSH_Node1> <SSH_Node2>"
    echo ""
    echo "Run all_gather_perf across two nodes:"
    echo "  nccl-run <IP_Node1> <IP_Node2> [interface]"
    echo ""
    echo "Measure raw RDMA, with no NCCL involved (fabric vs NCCL):"
    echo "  nccl-rdma-check <IP_Server> <IP_Client>"
    echo ""
  '';
}
