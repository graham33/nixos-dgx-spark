{ config, lib, pkgs, ... }:

let
  baseKernel = pkgs.linux_6_17;
  nvidiaKernelVersion = "6.17.1";
  nvidiaKernel = pkgs.linuxPackagesFor (baseKernel.override {
    argsOverride = rec {
      # Use the NVIDIA kernel source from
      # https://github.com/NVIDIA/NV-Kernels/commits/24.04_linux-nvidia-6.17-next/
      src = pkgs.fetchFromGitHub {
        owner = "NVIDIA";
        repo = "NV-Kernels";
        rev = "47ca203bcc5f4e1580c06fe1074d71497462ac8b";
        hash = "sha256-lPp7RFvZcPhV5v6FOxCVIB53vpNujvvP0NAW6iRaiF8=";
      };

      version = "${nvidiaKernelVersion}-nvidia";
      modDirVersion = nvidiaKernelVersion;
      # Use NVIDIA-patched defconfig from the source rather than the NixOS one
      defconfig = "defconfig";

      enableCommonConfig = false;
      
      structuredExtraConfig = with lib.kernel; {
        # NVIDIA-specific kernel configuration from debian.nvidia-6.17 annotations
        # See https://github.com/NVIDIA/NV-Kernels/blob/24.04_linux-nvidia-6.17-next/debian.nvidia-6.17/config/annotations
        # ARM64 errata and workarounds for Grace enablement
        ARM64_CONTPTE = yes;
        ARM64_ERRATUM_1902691 = yes;
        ARM64_ERRATUM_2038923 = yes;
        ARM64_ERRATUM_2064142 = yes;
        ARM64_ERRATUM_2119858 = yes;
        ARM64_ERRATUM_2139208 = yes;
        ARM64_ERRATUM_2224489 = yes;
        ARM64_ERRATUM_2253138 = yes;
        ARM64_WORKAROUND_TRBE_OVERWRITE_FILL_MODE = yes;
        ARM64_WORKAROUND_TRBE_WRITE_OUT_OF_RANGE = yes;

        # ARM64 firmware and IOMMU configuration
        ARM_FFA_TRANSPORT = yes;
        ARM_SMMU_V3_IOMMUFD = yes;
        ACPI_FFH = yes; # Required for NVIDIA_FFA_EC

        # CoreSight debugging support for Grace enablement
        CORESIGHT_CTCU = module;
        CORESIGHT_LINKS_AND_SINKS = module;
        CORESIGHT_SOURCE_ETM4X = module;
        CORESIGHT_TRBE = module;

        # Performance optimizations for NVIDIA workloads
        CPU_FREQ_DEFAULT_GOV_PERFORMANCE = yes;
        IOMMU_DEFAULT_PASSTHROUGH = yes;
        PREEMPT_NONE = yes;

        # NVIDIA-specific hardware support
        DRM_NOUVEAU = no; # Disable nouveau for NVIDIA kernels
        NVIDIA_FFA_EC = yes;
        PID_IN_CONTEXTIDR = yes;

        # Hardware configuration
        BCH = yes; # Essential for boot on ARM64
        MTD_NAND_CORE = yes;
        MTD_NAND_ECC = yes; # Enables ECC engine support
        MTD_NAND_ECC_SW_BCH = yes; # This selects BCH
        NR_CPUS = lib.mkForce (freeform "512");

        # Network drivers
        MANA_INFINIBAND = module;
        MICROSOFT_MANA = module;
        R8127 = module; # Use r8127 driver instead of r8169

        # Audio
        SND_HDA_ACPI = module; # Add support for ACPI-enumerated HDA

        # TPM/Security
        SPI_TEGRA210_QUAD = yes; # Ensures TPM is available before IMA initializes
        TCG_CRB = yes; # Required for TCG_ARM_CRB_FFA
        TCG_ARM_CRB_FFA = yes;
        TCG_TIS_SPI = yes;

        # Platform-specific
        PINCTRL_MT8901 = yes;

        KALLSYMS_SELFTEST = no;
      };
    };
  });
in {
  # Use the latest Linux kernel
  boot.kernelPackages = nvidiaKernel;

  boot.kernelParams = [
    "console=tty1"          # VGA console
  ];
  
  boot.blacklistedKernelModules = [
    "nouveau" # Ensure we use the NVIDIA open driver
    "r8169" # Use the r8127 driver in the NVIDIA kernel
  ];
  
  # Enable NVIDIA open driver
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;  # Use the open-source NVIDIA driver
    nvidiaPersistenced = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  hardware.enableRedistributableFirmware = true;
  
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;

  # Set up podman for NVIDIA containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  hardware.nvidia-container-toolkit.enable = true;
}
