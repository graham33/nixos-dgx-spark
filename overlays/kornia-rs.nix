# Bump kornia-rs to 0.1.10 to fix Rust compiler error on aarch64
# The upstream nixpkgs definition has aarch64-linux in badPlatforms due to rustc SIGSEGV
# This version fixes that issue
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      kornia-rs = python-prev.kornia-rs.overridePythonAttrs (oldAttrs: rec {
        version = "0.1.10";
        src = final.fetchFromGitHub {
          owner = "kornia";
          repo = "kornia-rs";
          tag = "v${version}";
          hash = "sha256-rC5NqyQah3D4tGLefS4cSIXA3+gQ0+4RNcXOcEYxryg=";
        };
        cargoDeps = final.rustPlatform.importCargoLock {
          lockFile = ../vendor/kornia-rs-0.1.10-Cargo.lock;
        };
        postPatch = ''
          ln -s ${../vendor/kornia-rs-0.1.10-Cargo.lock} kornia-py/Cargo.lock
        '';
        meta = oldAttrs.meta // { badPlatforms = [ ]; };
      });
    })
  ];
}
