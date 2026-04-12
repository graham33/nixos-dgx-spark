{ lib
, python3Packages
, fetchurl
, fetchFromGitHub
, autoPatchelfHook
, runCommand
, stdenv
}:

let
  openclawVersion = "2026.4.10";

  openShellCommunity = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "OpenShell-Community";
    rev = "36c558e929359830bf272868f42de7bf47bd2716";
    sha256 = "1s1hd9dsf2x4xn0pqyrnrl7fkrk2d2s2k2ms9haqpf6pd720wfi1";
  };
in
python3Packages.buildPythonPackage rec {
  pname = "openshell";
  version = "0.0.26";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/aa/c2/f09f730c894a9934e522b8c2855bb4790f9a3efeac448f727729f7306f5e/openshell-${version}-py3-none-manylinux_2_39_aarch64.whl";
    sha256 = "06623da6ef1290111d5f9f4175b070baeccc04b11d8606743436bec625d2450b";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dependencies = with python3Packages; [
    cloudpickle
    grpcio
    protobuf
  ];

  pythonImportsCheck = [ "openshell" ];

  # Patched openclaw sandbox template: fetches the upstream OpenShell-Community
  # sandbox files and pins openclaw to a version that includes the fetch-guard
  # proxy fix (openclaw/openclaw#50650). The upstream template still pins
  # openclaw@2026.3.11, where web_search/web_fetch bypass HTTPS_PROXY and fail
  # with EAI_AGAIN in proxy-only environments (OpenShell sandboxes, corporate
  # proxies).
  # Use with: openshell sandbox create --from ${openshell.openclawSandbox} ...
  passthru.openclawSandbox = runCommand "openclaw-sandbox" { } ''
    cp -r ${openShellCommunity}/sandboxes/openclaw $out
    chmod -R u+w $out
    substituteInPlace $out/Dockerfile \
      --replace-fail "openclaw@2026.3.11" "openclaw@${openclawVersion}"
  '';

  meta = {
    description = "OpenShell - the safe, private runtime for autonomous AI agents";
    homepage = "https://pypi.org/project/openshell/";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
