{ lib
, stdenv
, fetchurl
, autoPatchelfHook
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

  nativeBuildInputs = [ dpkg autoPatchelfHook ];

  buildInputs = [ pam ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
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
    cp usr/share/applications/*.desktop $out/share/applications/ || true
    cp -r usr/share/icons/* $out/share/icons/ || true

    # License
    mkdir -p $out/share/doc
    cp -r usr/share/doc/dgx-dashboard $out/share/doc/
  '';

  meta = {
    description = "NVIDIA DGX Dashboard - web interface for GPU telemetry, system updates, and JupyterLab";
    license = lib.licenses.bsd3;
    platforms = [ "aarch64-linux" ];
  };
}
