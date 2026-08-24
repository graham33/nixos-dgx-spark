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

      # gpuTargets is set to just "12.0" (Blackwell/Spark). Originally this
      # was to avoid compiling SM90 (Hopper) CUTLASS kernels, which take 16+
      # hours on aarch64 and aren't needed here; that no longer applies now
      # cudaCapabilities is [ "12.0" "12.1" ]. It still matters because under
      # CUDA 13 vllm's CUDA_SUPPORTED_ARCHS stops at 12.0 and it compiles the
      # family target 12.0f -- one cubin covering the whole SM12x family,
      # including the Spark's sm_121. Passing 12.1 makes
      # cuda_archs_loose_intersection fall back to a plain 12.1 target and
      # lose the family-conditional kernels.
      #
      # MAX_JOBS=8 caps build parallelism: vllm's nvcc/cicc uses ~6 GiB
      # per job, so unconstrained on Spark (20 cores, 128 GiB) the build
      # OOM-kills itself (~120 GiB needed). 8 leaves ~48 GiB headroom,
      # overriding nixpkgs' export MAX_JOBS="$NIX_BUILD_CORES".
      #
      # Upstream marked vllm broken under CUDA and bad on aarch64-linux
      # (NixOS/nixpkgs#553566), pending the 0.26.0 bump in
      # NixOS/nixpkgs#549327. The 0.24.0 build succeeds here with CUDA 13
      # and gpuTargets = [ "12.0" ], so unbreak it; drop this once the
      # upstream bump lands.
      vllm = (python-prev.vllm.override {
        gpuTargets = [ "12.0" ];
      }).overrideAttrs (old: {
        preConfigure = (old.preConfigure or "") + ''
          export MAX_JOBS=8
        '';
        meta = old.meta // {
          broken = false;
          badPlatforms = prev.lib.filter (p: p != "aarch64-linux") (old.meta.badPlatforms or [ ]);
        };
      });
    })
  ];
}
