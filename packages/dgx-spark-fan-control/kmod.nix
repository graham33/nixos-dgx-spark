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

  installPhase = ''
    runHook preInstall
    install -Dm644 -t "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon" \
      kernel/dgx_ec_fan_control.ko
    runHook postInstall
  '';

  # The NVIDIA kernel's modules are installed uncompressed, so the header
  # paths compiled into the .ko would pull kernel.dev into the closure (see
  # scrubKernelDevRefs in modules/dgx-spark.nix).
  postFixup = ''
    remove-references-to -t ${kernel.dev} \
      "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/hwmon/dgx_ec_fan_control.ko"
  '';

  meta = {
    description = "DGX Spark EC additive fan-floor cooling device driver";
    homepage = "https://github.com/christopherowen/dgx-spark-fan-control";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
