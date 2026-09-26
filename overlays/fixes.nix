# Nixpkgs fixes overlay
# Workarounds for packages that are broken or need adjustments on aarch64-linux / CUDA 13
final: prev: {
  # Switch to CUDA 13.4
  cudaPackages = prev.cudaPackages_13_4;

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

      # nixpkgs picks cuda-bindings' source and patch from a table keyed on the
      # CUDA major.minor version, and that table stops at 13.3 -- on nixpkgs
      # master too, as of 2026-09-26. Under CUDA 13.4 it throws "Unsupported
      # cuda-bindings version: 13.4" during evaluation, which takes vllm with
      # it (via tokenspeed-mla -> nvidia-cutlass-dsl ->
      # nvidia-cutlass-dsl-libs-base) and so breaks the vllm-nix devShell.
      #
      # cuda-python 13.4 also reworked how it opens libraries: cyruntime.pyx.in
      # and _bindings/cydriver.pyx.in are gone, and every library now goes
      # through cuda.pathfinder in _internal/<lib>_linux.pyx. Upstream's patch
      # no longer applies, but the call sites are uniform now, so rewriting
      # them is shorter than porting a static patch. The aim is the same as
      # upstream's: cuda.pathfinder discovers libraries through pip wheels and
      # the dynamic linker's search path, and finds nothing under /nix/store.
      #
      # Every attribute that reads the version table has to be replaced or
      # evaluation re-throws, which is why the override is this broad. Drop it
      # once nixpkgs ships a 13_4.nix.
      cuda-bindings =
        let
          cudaPackages = final.cudaPackages;
          libDir = pkg: "${prev.lib.getLib pkg}/lib";
          driverDir = "${final.addDriverRunpath.driverLink}/lib";

          # cuda.pathfinder library name -> the _internal/*_linux.pyx that
          # loads it, and where that library actually lives. libcuda and
          # libnvidia-ml come from the driver rather than the toolkit;
          # cuda_compat is not an alternative here, as this overlay nulls it
          # for linux-sbsa. cudla_linux.pyx is deliberately left alone --
          # libcudla has no linux-sbsa source, so there is nothing to point
          # it at.
          loaders = {
            cuda = { file = "driver"; path = "${driverDir}/libcuda.so.1"; };
            cudart = { file = "runtime"; path = "${libDir cudaPackages.cuda_cudart}/libcudart.so"; };
            cufile = { file = "cufile"; path = "${libDir cudaPackages.libcufile}/libcufile.so"; };
            nvfatbin = { file = "nvfatbin"; path = "${libDir cudaPackages.libnvfatbin}/libnvfatbin.so"; };
            nvJitLink = { file = "nvjitlink"; path = "${libDir cudaPackages.libnvjitlink}/libnvJitLink.so"; };
            nvml = { file = "nvml"; path = "${driverDir}/libnvidia-ml.so"; };
            nvrtc = { file = "nvrtc"; path = "${libDir cudaPackages.cuda_nvrtc}/libnvrtc.so"; };
            nvvm = { file = "nvvm"; path = "${libDir cudaPackages.libnvvm}/libnvvm.so"; };
          };

          rewriteLoader = name: { file, path }: ''
            substituteInPlace cuda/bindings/_internal/${file}_linux.pyx \
              --replace-fail \
                'from cuda.pathfinder import load_nvidia_dynamic_lib' \
                'from ctypes import CDLL' \
              --replace-fail \
                'load_nvidia_dynamic_lib("${name}")' \
                'CDLL("${path}")' \
              --replace-fail '._handle_uint' '._handle'
          '';
        in
        python-prev.cuda-bindings.overridePythonAttrs (_: {
          version = "13.4.3";

          src = final.fetchFromGitHub {
            owner = "NVIDIA";
            repo = "cuda-python";
            tag = "v13.4.3";
            hash = "sha256-U6n4qBnL3Nvd6BuTqeshpkLh9alPlkbuyuaJR3J/UPk=";
          };

          patches = [ ];

          postPatch = prev.lib.concatStrings (prev.lib.mapAttrsToList rewriteLoader loaders)
            + ''
            # A ctypes CDLL has no abs_path; only the cudart loader reports
            # one, in an error message.
            substituteInPlace cuda/bindings/_internal/runtime_linux.pyx \
              --replace-fail 'loaded_dl.abs_path' 'loaded_dl._name'
          '';

          pythonImportsCheck = [
            "cuda"
            "cuda.bindings.cufile"
            "cuda.bindings.driver"
            "cuda.bindings.nvfatbin"
            "cuda.bindings.nvjitlink"
            "cuda.bindings.nvml"
            "cuda.bindings.nvrtc"
            "cuda.bindings.nvvm"
            "cuda.bindings.runtime"
          ];

          # doCheck is off upstream (the tests want a GPU), so this list only
          # affects the passthru.gpuCheck variant.
          disabledTests = [ ];
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
