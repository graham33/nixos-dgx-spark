{ lib
, python3Packages
, fetchurl
, autoPatchelfHook
, stdenv
}:

python3Packages.buildPythonPackage rec {
  pname = "openshell";
  version = "0.0.22";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/aa/16/8b46928113683fd8a9afbcb7cde00e03e88be90fac1b94e2454ac8415357/openshell-${version}-py3-none-manylinux_2_39_aarch64.whl";
    sha256 = "983c89c2b59833bec5f2a81a4d12aaae3ad17cc6fd913a6f26b5d1a63d936aed";
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
