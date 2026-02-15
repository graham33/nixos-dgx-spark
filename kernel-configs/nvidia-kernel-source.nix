let
  nvidiaKernelRev = "47ca203bcc5f4e1580c06fe1074d71497462ac8b";
  nvidiaKernelHash = "sha256-lPp7RFvZcPhV5v6FOxCVIB53vpNujvvP0NAW6iRaiF8=";
  nvidiaKernelVersion = "6.17.1";
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
