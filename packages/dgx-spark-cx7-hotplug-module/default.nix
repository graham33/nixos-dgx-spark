{ lib
, stdenv
, writeText
, kernel
, src
,
}:

let
  kbuildFile = writeText "dgx-spark-cx7-hotplug-kbuild" ''
    obj-m += mtk-pcie-hotplug.o
  '';
in
stdenv.mkDerivation rec {
  pname = "dgx-spark-cx7-hotplug-module";
  version = kernel.modDirVersion;

  inherit src;

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildPhase = ''
    runHook preBuild

    cp "$src/drivers/platform/arm64/nvidia/mtk-pcie-hotplug.c" mtk-pcie-hotplug.c
    cp "${kbuildFile}" Makefile
    make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
      M="$PWD" \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm444 mtk-pcie-hotplug.ko \
      "$out/lib/modules/${kernel.modDirVersion}/extra/mtk-pcie-hotplug.ko"

    runHook postInstall
  '';

  meta = {
    description = "ConnectX-7 PCIe hotplug kernel module for NVIDIA DGX Spark";
    homepage = "https://github.com/NVIDIA/NV-Kernels";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
