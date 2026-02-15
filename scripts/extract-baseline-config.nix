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

  baselineKernel = pkgs.linuxPackagesFor (
    pkgs.linux_6_17.override {
      argsOverride = {
        src = kernelSource.mkNvidiaKernelSource pkgs;
        version = "${kernelSource.nvidiaKernelVersion}-nvidia-baseline";
        modDirVersion = kernelSource.nvidiaKernelVersion;
        kernelPatches = [ ];
      };

      enableCommonConfig = true;
      ignoreConfigErrors = true;
      structuredExtraConfig = { };
    }
  );
in
baselineKernel.kernel.configfile
