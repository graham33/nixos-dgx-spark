{ lib
, stdenv
, fetchFromGitHub
, kernel
, kernelModuleMakeFlags
, removeReferencesTo
,
}:

let
  source = import ./source.nix { inherit fetchFromGitHub; };
in
stdenv.mkDerivation {
  pname = "dgx-spark-fan-control-kmod";
  version = "${source.version}-${kernel.version}";
  inherit (source) src;

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ removeReferencesTo ];

  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "kernel"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  # Install through the kernel's modules_install rather than copying the .ko,
  # as nixpkgs now does for its own out-of-tree modules: with the
  # kernelModuleMakeFlags' cmd_sign, it strips the module, signs it with
  # kmodigest and writes the matching .ko.cer. NixOS needs that certificate:
  # aggregateModules merges one per external module into modules.cer, and
  # fails the system build if it is missing. The module's own Makefile has no
  # install target, so call kbuild directly.
  #
  # The NVIDIA kernel's modules are installed uncompressed, so the header
  # paths compiled into the .ko would pull kernel.dev into the closure (see
  # scrubKernelDevRefs in modules/dgx-spark.nix). Scrub them before signing:
  # rewriting a signed module breaks its signature.
  installPhase = ''
    runHook preInstall
    remove-references-to -t ${kernel.dev} kernel/dgx_ec_fan_control.ko
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      ${lib.escapeShellArgs kernelModuleMakeFlags} \
      M="$PWD/kernel" \
      INSTALL_MOD_PATH="$out" \
      INSTALL_MOD_DIR=kernel/drivers/hwmon \
      INSTALL_MOD_STRIP=1 \
      DEPMOD=true \
      modules_install
    runHook postInstall
  '';

  # fixupPhase would strip the module again, and strip drops the appended
  # signature. It is already stripped.
  stripExclude = [ "*.ko" ];

  meta = {
    description = "DGX Spark EC additive fan-floor cooling device driver";
    homepage = "https://github.com/christopherowen/dgx-spark-fan-control";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
