let
  nixpkgs = builtins.getFlake "nixpkgs";

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;

  pkgs = import nixpkgs {
    system = "aarch64-linux";
    config.allowUnfree = true;
    overlays = [
      (import ../overlays/linux-6.17.nix)
    ];
  };

  fetchedSource = kernelSource.mkNvidiaKernelSource pkgs;
in
fetchedSource
