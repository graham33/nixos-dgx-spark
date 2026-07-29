{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, pkg-config
, rdma-core
, pciutils
}:

# The RDMA microbenchmarks (ib_write_bw, ib_read_lat, ...). Not in nixpkgs, and
# rdma-core does not bundle them, but they are how NVIDIA's own DGX Spark
# instructions verify that a 200GbE QSFP link performs -- and the only way to
# measure the fabric without NCCL, CUDA and MPI in the path.
stdenv.mkDerivation rec {
  pname = "perftest";
  version = "26.04.17";

  src = fetchFromGitHub {
    owner = "linux-rdma";
    repo = "perftest";
    rev = version;
    hash = "sha256-oNvzQubmslZ4JUNww/wvWd54JDsDLamCDlorHWlNtaY=";
  };

  nativeBuildInputs = [ autoreconfHook pkg-config ];
  buildInputs = [ rdma-core pciutils ];

  # CUDA support is deliberately left off: it would pull the whole toolkit in
  # for the GPU-direct variants, and the point here is a GPU-free baseline.
  configureFlags = [ "--without-cuda" ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Infiniband/RoCE verbs performance tests";
    homepage = "https://github.com/linux-rdma/perftest";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    mainProgram = "ib_write_bw";
  };
}
