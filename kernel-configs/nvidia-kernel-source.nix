let
  # Tag Ubuntu-nvidia-7.0-7.0.0-1019.19_24.04.2. Pin tags, not branch heads:
  # NVIDIA rewrites the -next branches on every release.
  nvidiaKernelRev = "ae07646a606b3f18707246b0762464452cb40cbe";
  nvidiaKernelHash = "sha256-wE7NtppnYtNlMoKhFBBDab0t5MSg46cBEW39duFO2N8=";
  nvidiaKernelVersion = "7.0.14";
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
