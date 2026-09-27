let
  nixpkgs = (builtins.getFlake (toString ../.)).inputs.nixpkgs;

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;

  pkgs = import nixpkgs {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };

  baselineKernel = pkgs.linuxPackagesFor (
    pkgs.buildLinux {
      src = kernelSource.mkNvidiaKernelSource pkgs;
      version = "${kernelSource.nvidiaKernelVersion}-nvidia-baseline";
      modDirVersion = kernelSource.nvidiaKernelVersion;
      kernelPatches = [ ];

      ignoreConfigErrors = true;
      structuredExtraConfig = { };
    }
  );
in
baselineKernel.kernel.configfile
