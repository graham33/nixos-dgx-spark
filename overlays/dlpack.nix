final: prev: {
  dlpack = prev.stdenv.mkDerivation rec {
    pname = "dlpack";
    version = "1.2";

    src = prev.fetchFromGitHub {
      owner = "dmlc";
      repo = "dlpack";
      rev = "v${version}";
      hash = "sha256-9sKjRGnoaHLUXjDahyWrYYYdDQuqwJyL0hFo1YhGov4=";
    };

    nativeBuildInputs = [ prev.cmake ];

    # Header-only library
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/include
      cp -r $src/include/dlpack $out/include/
    '';

    meta = with prev.lib; {
      description = "Open in-memory tensor structure for sharing tensors among frameworks";
      homepage = "https://github.com/dmlc/dlpack";
      license = licenses.asl20;
      platforms = platforms.all;
    };
  };
}
