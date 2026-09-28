{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.hardware.dgx-spark;

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;

  # NVIDIA's arm64 kernel comes in two Debian flavours: nvidia (4K pages,
  # what DGX OS ships on the Spark) and nvidia-64k (what it ships on
  # GB200/GB300).
  flavourSuffix = optionalString cfg.use64kKernel "-64k";

  dgxKernelConfig = import
    (
      ../kernel-configs + "/nvidia-dgx-spark-${kernelSource.nvidiaKernelVersion}${flavourSuffix}.nix"
    )
    { inherit lib; };

  # buildLinux directly rather than overriding nixpkgs' linux_7_0, which
  # throws now that kernel.org has marked 7.0 end-of-life. NVIDIA still
  # maintains its 7.0 branch, and src, version and config all come from here
  # anyway.
  nvidiaKernel = pkgs.linuxPackagesFor (
    pkgs.buildLinux {
      src = kernelSource.mkNvidiaKernelSource pkgs;
      version = "${kernelSource.nvidiaKernelVersion}-nvidia${flavourSuffix}";
      modDirVersion = kernelSource.nvidiaKernelVersion;
      # buildLinux takes no default patches; these are the ones nixpkgs applies
      # to its own kernels, pointing the kernel at NixOS's helper paths.
      kernelPatches = with pkgs.kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ];
      extraMeta.branch = lib.versions.majorMinor kernelSource.nvidiaKernelVersion;

      ignoreConfigErrors = true;

      structuredExtraConfig =
        dgxKernelConfig
        // (with lib.kernel; {
          USB_STORAGE = yes;
          USB_UAS = yes;
          OVERLAY_FS = yes;

          UEVENT_HELPER = no;

          UBUNTU_HOST = no;

          # NVIDIA wants TCG_CRB=y and TCG_ARM_CRB_FFA=y. The baseline also ends
          # up with TCG_CRB=y, so the terse config omits it, but only because
          # IMA selects it later in the Kconfig walk: generate-config.pl first
          # answers TCG_CRB=m, then cannot answer y to TCG_ARM_CRB_FFA, which
          # depends on it. Answer TCG_CRB explicitly.
          TCG_CRB = yes;
        });
    }
  );

  # Strip embedded references to the kernel `-dev` output from .ko files. The
  # nvidia kernel-modules build (nixpkgs PR #498612) declares
  # `allowedReferences = [ ]` on the module derivation, but the .ko files end
  # up with __FILE__-derived header paths in `.rodata.str1.8` that point into
  # the kernel-dev store path, so the closure check fails. Run
  # remove-references-to as a postFixup to scrub them.
  #
  # Every kernel leaves these strings behind, stock nixpkgs ones included.
  # nixpkgs' common config sets MODULE_COMPRESS_ALL with XZ, though, and
  # compression hides the store hashes from Nix's reference scanner. NVIDIA's
  # config picks zstd and leaves MODULE_COMPRESS_ALL off, so these modules
  # are installed uncompressed and the references become visible.
  scrubKernelDevRefs = drv:
    drv.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        if [ -d "$out/lib/modules" ]; then
          find $out/lib/modules -name '*.ko' -print0 \
            | xargs -0 -r ${pkgs.removeReferencesTo}/bin/remove-references-to \
                -t ${config.boot.kernelPackages.kernel.dev}
        fi
      '';
    });
in
{
  imports = [
    ./dgx-dashboard.nix
    ./dgx-spark-connectx7.nix
    ./vllm.nix
  ];

  options.hardware.dgx-spark = {
    enable = mkEnableOption "DGX Spark hardware support";

    useNvidiaKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the NVIDIA kernel instead of the standard NixOS kernel";
    };

    use64kKernel = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Build the NVIDIA kernel with 64K pages (NVIDIA's `nvidia-64k` flavour)
        instead of 4K. This can cut TLB pressure for large-memory GPU
        workloads.

        DGX OS ships the 4K flavour on the Spark and 64K only on GB200/GB300,
        so this is untested on GB10. 64K pages also disable 32-bit
        compatibility (no AArch32 binaries); an existing swap area must be
        re-created with `mkswap`; and prebuilt binaries that assume 4K pages,
        such as a bundled jemalloc built for 4K or x86 emulators like
        FEX/box64, may fail.
      '';
    };

    cppcAutonomousMode = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable CPPC autonomous selection mode (`cppc_cpufreq.auto_sel_mode=1`).

        On the GB10, without autonomous CPPC the memory fabric never enters
        autonomous performance management, which cripples single-thread memory
        bandwidth (~3x lower) and llama.cpp prompt-processing (~4% lower) vs
        stock DGX OS. Stock DGX OS boots with autonomous mode enabled; the
        NVIDIA `-next` kernel ships the driver support but defaults it off, so
        it must be enabled explicitly.

        Requires the NVIDIA kernel (`useNvidiaKernel = true`), whose cppc_cpufreq
        driver carries the autonomous-mode series.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.use64kKernel -> cfg.useNvidiaKernel;
        message = "hardware.dgx-spark.use64kKernel requires hardware.dgx-spark.useNvidiaKernel.";
      }
    ];

    # Add the Flox binary cache as a substituter for pre-built CUDA packages.
    # Flox is authorized by NVIDIA to redistribute CUDA binaries, so packages
    # like cudatoolkit, nccl, cuDNN, torch, etc. can be fetched as pre-built
    # binaries instead of compiling from source.
    # https://flox.dev/blog/the-flox-catalog-now-contains-nvidia-cuda/
    nix.settings = {
      extra-substituters = [ "https://cache.flox.dev" ];
      extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
    };

    boot.kernelPackages = if cfg.useNvidiaKernel then nvidiaKernel else pkgs.linuxPackages_latest;

    boot.kernelParams = [
      "console=tty1"
      # Module-autoload kill switches for rarely needed attack surface that
      # has recently produced local privilege escalations:
      #
      #   algif_aead  — CVE-2026-31431 "Copy Fail" (AF_ALG AEAD local privesc)
      #   esp4, esp6  — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
      #   rxrpc       — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
      #
      # The pinned NVIDIA kernel carries the fixes for all three, so this is
      # defence in depth against the next bug there. The cost is that IPsec
      # ESP and AF_RXRPC are unavailable.
      #
      # Each of these modules is requested by name from a kernel subsystem
      # (AF_ALG, xfrm_user, AF_RXRPC respectively), bypassing modprobe alias
      # blacklists. `module_blacklist=` is a kernel-level kill switch:
      # request_module() refuses to invoke modprobe at all, so this is
      # robust against both autoload (e.g. socket(AF_ALG)+bind("aead")) and
      # explicit `modprobe`. NB: `boot.blacklistedKernelModules` alone is
      # NOT sufficient — modprobe's `blacklist` directive only blocks
      # alias-based autoloads, and these kernel paths request the module
      # by name (after dash/underscore normalisation), bypassing it.
      # Requires a reboot to apply.
      "module_blacklist=algif_aead,esp4,esp6,rxrpc"

      # The remaining parameters mirror what DGX OS puts on the Spark's
      # command line, each shipped as its own nvidia-spark-* package in
      # NVIDIA's BaseOS apt repository.
      #
      # nvidia-spark-grub-pci: clamp every device to the lowest Max Payload
      # Size supported across the PCIe bus.
      "pci=pcie_bus_safe"
      # nvidia-spark-initcall-bl: keep the Tegra CBB (control backbone) error
      # driver, which binds to the GB10's fabrics over ACPI, from initialising.
      "initcall_blacklist=tegra234_cbb_init"
      # nvidia-spark-grub-kho: disable Kexec HandOver. NVIDIA's 7.0 config sets
      # KEXEC_HANDOVER_ENABLE_DEFAULT with CMA_SIZE_MBYTES=0, which leaves the
      # KHO scratch area as unaccounted MIGRATE_CMA memory; long-term pins
      # such as ibv_reg_mr then fail with ENOMEM under memory pressure,
      # breaking NCCL and RoCE.
      "kho=off"
    ] ++ lib.optional (cfg.useNvidiaKernel && cfg.cppcAutonomousMode) "cppc_cpufreq.auto_sel_mode=1";

    boot.blacklistedKernelModules = [
      "nouveau"
      "r8169"
      "coresight_etm4x"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaPersistenced = true;
      nvidiaSettings = true;
      # Apply scrubKernelDevRefs to the .open / .mod kernel module variants —
      # bypass boot.kernelPackages.apply (which chains another `.extend` and
      # re-evaluates `nvidiaPackages` through the makeExtensible fixed point,
      # discarding any overrides we'd put on the kernel package set itself).
      #
      # `latest` rather than `production`: the driver's CUDA version must be at
      # least the toolkit's, or the driver cannot JIT the toolkit's PTX (minor
      # version compatibility does not cover PTX JIT), and any PTX-only kernel
      # fails with cudaErrorUnsupportedPtxVersion. The overlay builds against
      # CUDA 13.4, which pairs with the R615 branch; `production` is R595
      # (CUDA 13.2). NVIDIA only supports its DGX OS driver (R580) on the Spark.
      package =
        let
          driver = config.boot.kernelPackages.nvidiaPackages.latest;
        in
        driver
        // {
          open = scrubKernelDevRefs driver.open;
          mod = scrubKernelDevRefs driver.mod;
        };
    };

    hardware.enableRedistributableFirmware = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;
    # Compile CUDA code only for the Spark's GB10 Blackwell GPU. Without this,
    # packages like ucc build for all nine architectures nixpkgs supports
    # (sm_75 through sm_121), which can exhaust memory and OOM a rebuild.
    #
    # NB: this does not match the Flox cache, which is built with nixpkgs'
    # default (full) capability list, so CUDA-dependent packages are rebuilt
    # from source. Set `nixpkgs.config.cudaCapabilities = [ ]` to restore the
    # default and get the cache hits back -- see "Matching the Flox cache with
    # cudaCapabilities" in the README for the trade-off.
    nixpkgs.config.cudaCapabilities = [ "12.0" "12.1" ];

    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # Trust the podman bridge so containers can reach host services
    networking.firewall.trustedInterfaces = [ "podman+" ];

    hardware.nvidia-container-toolkit.enable = true;

    # RDMA over the ConnectX ports needs to pin the memory it registers, and
    # the NixOS default memlock ceiling of 8 MB is far too low: ibv_reg_mr
    # fails and UCX floods the log with "Cannot allocate memory ... Please set
    # max locked memory (ulimit -l) to 'unlimited'", which then looks like a
    # network fault further up. Stock DGX OS sets a limit of roughly the whole
    # of RAM, so without this a Spark pair is asymmetric and multi-node runs
    # fail on the NixOS side only. Note the *hard* limit matters -- an
    # unprivileged `ulimit -l` cannot raise it.
    security.pam.loginLimits = [
      { domain = "*"; type = "soft"; item = "memlock"; value = "unlimited"; }
      { domain = "*"; type = "hard"; item = "memlock"; value = "unlimited"; }
    ];

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia
      iperf3
      ethtool
      rdma-core
    ];

    services.dgx-dashboard.enable = true;
    services.fwupd.enable = true;
  };
}
