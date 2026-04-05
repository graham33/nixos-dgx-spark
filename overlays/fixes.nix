# Nixpkgs fixes overlay
# Workarounds for packages that are broken or need adjustments on aarch64-linux / CUDA 13
final: prev: {
  # Switch to CUDA 13.2
  cudaPackages = prev.cudaPackages_13_2;

  _cuda = prev._cuda.extend (
    _: prevAttrs: {
      extensions = prevAttrs.extensions ++ [
        # Disable cuda_compat for linux-sbsa (aarch64 servers)
        # cuda_compat has src = null for linux-sbsa even though meta.platforms claims support
        (prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux")
          (_: _: { cuda_compat = null; }))
        # Bump NCCL to v2.28.9-1 (nixpkgs has v2.28.7-1)
        (_: cudaPrev: {
          nccl = cudaPrev.nccl.overrideAttrs (oldAttrs: {
            version = "2.28.9-1";
            src = prev.fetchFromGitHub {
              owner = "NVIDIA";
              repo = "nccl";
              rev = "v2.28.9-1";
              hash = "sha256-1nNLcS/F0HsGbYf327TLX+ZVI13YcrrhpLqbGVuml2g=";
            };
          });
        })
      ];
    }
  );

  # Header-only tensor sharing library (not yet in nixpkgs)
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

  # Disable CUDA support in OpenCV (not compatible with CUDA 13)
  opencv4 = prev.opencv4.override {
    enableCuda = false;
  };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # Mark torch as not broken (upstream marks it broken for CUDA 13)
      torch = python-prev.torch.overridePythonAttrs (oldAttrs: {
        meta = oldAttrs.meta // { broken = false; };
      });

      # Disable tests that fail on aarch64 (cpuinfo init failure in nix build sandbox)
      accelerate = python-prev.accelerate.overridePythonAttrs { doCheck = false; };
      compressed-tensors = python-prev.compressed-tensors.overridePythonAttrs { doCheck = false; };
      peft = python-prev.peft.overridePythonAttrs { doCheck = false; };
      # Disable torchaudio tests (too slow)
      torchaudio = python-prev.torchaudio.overridePythonAttrs { doCheck = false; };

      # Bump kornia-rs to 0.1.10 to fix Rust compiler SIGSEGV on aarch64
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

      # Fix xgrammar badPlatforms for aarch64-linux and upgrade to 0.1.27
      xgrammar = python-prev.xgrammar.overridePythonAttrs (oldAttrs: {
        version = "0.1.27";
        src = prev.fetchFromGitHub {
          owner = "mlc-ai";
          repo = "xgrammar";
          rev = "v0.1.27";
          hash = "sha256-XwMSYgXoNKglN772vtrqFOtq//trpIH9Oi/hk++Tf84=";
        };
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ final.dlpack ];
        # Disable -Werror to avoid compilation failures with gcc 14
        env = (oldAttrs.env or { }) // {
          NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error";
        };
        # Disable test that requires network access to huggingface.co and slow tests
        disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [
          "tests/python/test_structural_tag_converter.py"
          "tests/python/test_serialization.py"
        ];
        meta = oldAttrs.meta // {
          badPlatforms = [ ];
        };
      });

      # Override cupy to use cudaPackages from final scope instead of hardcoded cuDNN 8.9.7
      # This is needed for CUDA 13 compatibility where cuDNN 8.9.7 is not available
      cupy = python-prev.cupy.override {
        cudaPackages = final.cudaPackages;
      };

      # Override bitsandbytes to add cuda_crt to build inputs for CUDA 13
      # CUDA 13 split crt headers into a separate package
      bitsandbytes = python-prev.bitsandbytes.overridePythonAttrs (oldAttrs: prev.lib.optionalAttrs (final.cudaPackages ? cuda_crt) {
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ final.cudaPackages.cuda_crt ];
      });

      # Override transformers to not include tensorflow in optional dependencies
      transformers = python-prev.transformers.overridePythonAttrs (oldAttrs: {
        optional-dependencies = prev.lib.mapAttrs
          (name: deps:
            if name == "tf" then
              prev.lib.filter (dep: !(prev.lib.hasInfix "tensorflow" (dep.pname or ""))) deps
            else deps
          )
          (oldAttrs.optional-dependencies or { });
      });

      # Override outlines to not include tensorflow in tests
      outlines = python-prev.outlines.overridePythonAttrs (oldAttrs: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    })
  ];
}
