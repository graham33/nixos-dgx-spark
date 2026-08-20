{ lib
, stdenv
, fetchgit
, writeText
, kernel
,
}:

let
  kbuildFile = writeText "dgx-spark-cx7-hotplug-kbuild" ''
    obj-m += mtk-pcie-hotplug.o
  '';
in
stdenv.mkDerivation rec {
  pname = "dgx-spark-cx7-hotplug-module";
  version = "6.17.0-1026.26";

  src = fetchgit {
    url = "https://git.launchpad.net/ubuntu/+source/linux-nvidia-6.17";
    tag = "applied/${version}";
    hash = "sha256-/0iieKunzihloKaXEnLwJP7Z7VZqgiLqQFDyV/Jv788=";
    rootDir = "drivers/platform/arm64/nvidia";
  };

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  buildPhase = ''
    runHook preBuild

    cp "$src/mtk-pcie-hotplug.c" mtk-pcie-hotplug.c
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
    homepage = "https://launchpad.net/ubuntu/+source/linux-nvidia-6.17";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
