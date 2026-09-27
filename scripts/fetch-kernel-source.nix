let
  nixpkgs = (builtins.getFlake (toString ../.)).inputs.nixpkgs;

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;

  pkgs = import nixpkgs { system = "aarch64-linux"; };

  fetchedSource = kernelSource.mkNvidiaKernelSource pkgs;
in
fetchedSource
