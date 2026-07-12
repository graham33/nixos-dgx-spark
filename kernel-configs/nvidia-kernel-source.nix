let
  nvidiaKernelRev = "aea4c7df51fd59f7717d7668110a803d95c7a3f1";
  nvidiaKernelHash = "sha256-195eFIcuND41riRxE342FM5O7c515sG8ioQE5PE74xU=";
  nvidiaKernelVersion = "6.17.13";
in
{
  inherit nvidiaKernelRev nvidiaKernelHash nvidiaKernelVersion;

  mkNvidiaKernelSource =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "NVIDIA";
      repo = "NV-Kernels";
      rev = nvidiaKernelRev;
      hash = nvidiaKernelHash;
    };
}
