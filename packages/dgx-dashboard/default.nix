{ lib
, stdenv
, fetchurl
, patchelf
, dpkg
, pam
}:

stdenv.mkDerivation rec {
  pname = "dgx-dashboard";
  version = "0.23.3";

  src = fetchurl {
    url = "https://repo.download.nvidia.com/baseos/ubuntu/noble/arm64/pool/dgx/d/dgx-dashboard/dgx-dashboard_${version}_arm64.deb";
    sha256 = "1c02b4d8f763cdfe4a19fcefaa20417b953dba7c060740037876e980ce4770f5";
  };

  # Not autoPatchelfHook: patchelf 0.19.2 mis-rewrites dashboard-admin when
  # --set-interpreter is followed by --set-rpath, which is the order
  # auto-patchelf uses. The first LOAD segment shrinks to 0x300 bytes and
  # stops covering the program headers (readelf: "the PHDR segment is not
  # covered by a LOAD segment"), and the binary segfaults in ld.so before
  # main. The same two edits in the opposite order produce a working binary,
  # as does patchelf 0.15.2. dashboard-service, a Go binary, is unaffected
  # either way. Patch both by hand, rpath first.
  nativeBuildInputs = [ dpkg patchelf ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/dgx-dashboard $out/share

    # Main service binary
    install -m755 opt/nvidia/dgx-dashboard-service/dashboard-service $out/bin/dashboard-service

    # Admin binary
    install -m755 opt/nvidia/dgx-dashboard/dashboard-admin $out/bin/dashboard-admin

    # Reboot helper
    install -m755 opt/nvidia/dgx-dashboard/dgx-dashboard-reboot.sh $out/lib/dgx-dashboard/

    # Default port config
    install -m644 opt/nvidia/dgx-dashboard-service/ports.env $out/lib/dgx-dashboard/

    # D-Bus policy
    mkdir -p $out/share/dbus-1/system.d
    cp etc/dbus-1/system.d/*.conf $out/share/dbus-1/system.d/

    # Desktop entry and icon
    mkdir -p $out/share/applications $out/share/icons
    cp usr/share/applications/*.desktop $out/share/applications/
    cp -r usr/share/icons/* $out/share/icons/

    # License
    mkdir -p $out/share/doc
    cp -r usr/share/doc/dgx-dashboard $out/share/doc/

    runHook postInstall
  '';

  postFixup = ''
    patchelf --set-rpath ${lib.makeLibraryPath [ pam ]} $out/bin/dashboard-admin
    for bin in $out/bin/dashboard-admin $out/bin/dashboard-service; do
      patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$bin"
    done
  '';

  meta = {
    description = "NVIDIA DGX Dashboard - web interface for GPU telemetry, system updates, and JupyterLab";
    # usr/share/doc/dgx-dashboard/copyright: "License: Proprietary",
    # governed by the bundled EULA.txt.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-linux" ];
  };
}
