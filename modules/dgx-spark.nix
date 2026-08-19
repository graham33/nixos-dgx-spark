{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.hardware.dgx-spark;

  kernelSource = import ../kernel-configs/nvidia-kernel-source.nix;
  baseKernel = pkgs.linux_6_17;

  dgxKernelConfig = import
    (
      ../kernel-configs + "/nvidia-dgx-spark-${kernelSource.nvidiaKernelVersion}.nix"
    )
    { inherit lib; };

  pageSize64kConfig = import ../kernel-configs/page-size-64k.nix { inherit lib; };

  nvidiaKernelPatches = [
    {
      name = "rust-gendwarfksyms-fix";
      patch = ../patches/rust-gendwarfksyms-fix.patch;
    }
  ];

  # NVIDIA ships the DGX kernel in two arm64 flavours, 4K- and 64K-page. Build
  # the selected one: the page size is a compile-time property of the kernel
  # image, so the two flavours are separate kernel packages rather than a knob
  # on a shared one (matching how nixos-apple-silicon bakes ARM64_16K_PAGES
  # into `linux-asahi`, and how NVIDIA builds `arm64-nvidia` vs
  # `arm64-nvidia-64k`). The `//` ordering matters: the 64K deltas replace the
  # 4K values the generated config force-sets for PGTABLE_LEVELS and friends.
  mkNvidiaKernel = pageSize: pkgs.linuxPackagesFor (
    baseKernel.override {
      argsOverride = {
        src = kernelSource.mkNvidiaKernelSource pkgs;
        version = "${kernelSource.nvidiaKernelVersion}-nvidia";
        modDirVersion = kernelSource.nvidiaKernelVersion;
        kernelPatches = nvidiaKernelPatches;
      };

      enableCommonConfig = true;
      ignoreConfigErrors = true;

      structuredExtraConfig =
        dgxKernelConfig
        // (with lib.kernel; {
          SECURITY_APPARMOR_BOOTPARAM_VALUE = freeform "1";
          SECURITY_APPARMOR_RESTRICT_USERNS = lib.mkForce yes;

          USB_STORAGE = yes;
          USB_UAS = yes;
          OVERLAY_FS = yes;

          UEVENT_HELPER = no;

          UBUNTU_HOST = no;
        })
        // lib.optionalAttrs (pageSize == "64k") pageSize64kConfig;
    }
  );

  rawNvidiaKernel = mkNvidiaKernel cfg.kernelPageSize;

  # Strip embedded references to the kernel `-dev` output from .ko files. The
  # nvidia kernel-modules build (nixpkgs PR #498612) declares
  # `allowedReferences = [ ]` on the module derivation, but the .ko files end
  # up with __FILE__-derived header paths in `.rodata.str1.8` that point into
  # the kernel-dev store path, so the closure check fails. Run
  # remove-references-to as a postFixup to scrub them. Stock x86_64 kernels
  # don't trigger this — the leak is specific to non-stock (e.g. patched
  # aarch64) kernels where the build environment leaves these strings around.
  scrubKernelDevRefs = drv:
    drv.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        if [ -d "$out/lib/modules" ]; then
          find $out/lib/modules -name '*.ko' -print0 \
            | xargs -0 -r ${pkgs.removeReferencesTo}/bin/remove-references-to \
                -t ${rawNvidiaKernel.kernel.dev}
        fi
      '';
    });

  nvidiaKernel = rawNvidiaKernel;
in
{
  imports = [
    ./dgx-dashboard.nix
    ./vllm.nix
  ];

  options.hardware.dgx-spark = {
    enable = mkEnableOption "DGX Spark hardware support";

    useNvidiaKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the NVIDIA kernel instead of the standard NixOS kernel";
    };

    kernelPageSize = mkOption {
      type = types.enum [ "4k" "64k" ];
      default = "4k";
      description = ''
        Page size of the NVIDIA kernel, matching NVIDIA's `arm64-nvidia` and
        `arm64-nvidia-64k` flavours. The default of 4K matches the stock
        `arm64-nvidia` flavour and every other aarch64 kernel in nixpkgs.

        64K pages cut TLB pressure and page-table walk depth (three levels
        rather than four), which can help large-footprint GPU workloads, at
        the cost of more memory wasted to internal fragmentation and no
        AArch32 userspace. Note that a 64K-page kernel refuses to load ELF
        binaries linked with 4K max-page-size alignment; the aarch64 toolchain
        defaults to 64K so nixpkgs-built code is fine, but vendored binaries
        (CUDA redistributables, prebuilt wheels) are worth checking.

        Changing this rebuilds the kernel and all out-of-tree modules from
        source -- there is no cached build for either flavour.

        Requires the NVIDIA kernel (`useNvidiaKernel = true`); the stock NixOS
        kernel is always 4K.
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
    # The page size is set via the NVIDIA kernel's structuredExtraConfig, so
    # it is silently ignored on the stock NixOS kernel path.
    assertions = [
      {
        assertion = cfg.kernelPageSize == "64k" -> cfg.useNvidiaKernel;
        message = ''
          hardware.dgx-spark.kernelPageSize = "64k" requires
          hardware.dgx-spark.useNvidiaKernel = true; the stock NixOS kernel is
          always built with 4K pages.
        '';
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

    nixpkgs.overlays = [ (import ../overlays/linux-6.17.nix) ];

    boot.kernelPackages = if cfg.useNvidiaKernel then nvidiaKernel else pkgs.linuxPackages_6_17;

    boot.kernelParams = [
      "console=tty1"
      # Module-autoload kill switches for kernel vulnerabilities with no
      # upstream patch at the time of writing:
      #
      #   algif_aead  — CVE-2026-31431 "Copy Fail" (AF_ALG AEAD local privesc)
      #   esp4, esp6  — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
      #   rxrpc       — CVE-2026-43284 / CVE-2026-43500 "Dirty Frag"
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
      package =
        let
          prod = config.boot.kernelPackages.nvidiaPackages.production;
        in
        prod
        // {
          open = scrubKernelDevRefs prod.open;
          mod = scrubKernelDevRefs prod.mod;
        };
    };

    hardware.enableRedistributableFirmware = true;

    nixpkgs.config.allowUnfree = true;
    nixpkgs.config.cudaSupport = true;
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
