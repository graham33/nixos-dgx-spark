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
      ];
    }
  );

  # Disable CUDA support in OpenCV (not compatible with CUDA 13)
  opencv4 = prev.opencv4.override {
    enableCuda = false;
  };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # compressed-tensors 0.17.1 imports psutil in its offload code but the
      # nixpkgs derivation doesn't propagate it.
      compressed-tensors = python-prev.compressed-tensors.overridePythonAttrs (oldAttrs: {
        dependencies = (oldAttrs.dependencies or [ ]) ++ [ python-final.psutil ];
      });
      # jupyter-server enters the vLLM closure via einops' test deps. Two
      # orphaned-kernel FD-leak / timeout tests are flaky under the nix
      # sandbox's low FD limits.
      jupyter-server = python-prev.jupyter-server.overridePythonAttrs (oldAttrs: {
        disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
          "test_no_fd_leak_on_disconnect_with_orphaned_kernel_info_channel"
          "test_disconnect_resolves_orphaned_kernel_info_future"
        ];
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

      # New deps required by vLLM 0.19.0
      kaldi-native-fbank = python-final.callPackage ../packages/kaldi-native-fbank { };
      opentelemetry-semantic-conventions-ai = python-final.callPackage ../packages/opentelemetry-semantic-conventions-ai { };

      # Bump vLLM to 0.19.0 for Qwen3.5 and Gemma 4 model support.
      # Uses the package definition from NixOS/nixpkgs#498040.
      # gpuTargets is set to just "12.0" (Blackwell/Spark) to avoid
      # compiling SM90 (Hopper) CUTLASS kernels which take 16+ hours
      # on aarch64 and aren't needed on this hardware.
      #
      # MAX_JOBS=8 caps build parallelism: vllm's nvcc/cicc uses ~6 GiB
      # per job, so unconstrained on Spark (20 cores, 128 GiB) the build
      # OOM-kills itself (~120 GiB needed). 8 leaves ~48 GiB headroom.
      # Done as an overlay-level override so packages/vllm itself matches
      # upstream nixpkgs (export MAX_JOBS="$NIX_BUILD_CORES").
      vllm = (python-final.callPackage ../packages/vllm {
        inherit (final) cudaPackages;
        gpuTargets = [ "12.0" ];
        # ROCm-only deps — not needed for CUDA
        amd-aiter = null;
        amd-quark = null;
        amdsmi = null;
        rocmPackages = { };
        pybind11 = python-final.pybind11;
      }).overrideAttrs (old: {
        preConfigure = (old.preConfigure or "") + ''
          export MAX_JOBS=8
        '';
      });
    })
  ];
}
