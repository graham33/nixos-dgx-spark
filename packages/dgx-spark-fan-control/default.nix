{ lib
, stdenv
, fetchFromGitHub
, python3
,
}:

let
  source = import ./source.nix { inherit fetchFromGitHub; };
in
stdenv.mkDerivation {
  pname = "dgx-spark-fan-control";
  inherit (source) version src;

  strictDeps = true;

  buildInputs = [ python3 ];
  nativeCheckInputs = [ python3 ];

  dontBuild = true;

  # Hardware-free tests of the curve policy, failure handling and the
  # driver's transaction logic, which they compile against a mocked FF-A
  # transport with $CC. test_build_sign covers the Secure Boot signing
  # scripts, which are not installed (NixOS builds the module itself).
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    rm tests/test_build_sign.py
    python3 -m unittest discover -s tests -v
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 userspace/dgx_fan_control.py "$out/bin/dgx-fan-control"
    install -Dm644 -t "$out/share/doc/dgx-spark-fan-control" README.md docs/*.md
    runHook postInstall
  '';

  meta = {
    description = "Additive fan-floor control and temperature curve for NVIDIA DGX Spark";
    homepage = "https://github.com/christopherowen/dgx-spark-fan-control";
    license = lib.licenses.gpl2Only;
    mainProgram = "dgx-fan-control";
    platforms = [ "aarch64-linux" ];
  };
}
