{ lib
, python3Packages
, fetchurl
, autoPatchelfHook
, stdenv
}:

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

  meta = {
    description = "OpenShell - the safe, private runtime for autonomous AI agents";
    homepage = "https://pypi.org/project/openshell/";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-linux" ];
  };
}
