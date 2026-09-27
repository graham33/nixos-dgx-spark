# Nixpkgs fixes overlay
# Workarounds for packages that are broken or need adjustments on aarch64-linux / CUDA 13
final: prev: {
  # Switch to CUDA 13.4.
  #
  # nixpkgs builds cuda-samples from the v13.0 tag for every CUDA 13.x, and
  # three of that release's samples (segmentationTreeThrust, particles and
  # smokeParticles) no longer compile against the CCCL 3.x shipped with CUDA
  # 13.4. Apply NVIDIA's fix, which moves them off thrust::make_tuple and
  # thrust::tuple onto the cuda::std equivalents. It landed after v13.0 but
  # applies cleanly to it.
  #
  # Moving to a newer sample release is not the easier fix it looks like:
  # v13.2 added an unconditional file(READ /etc/os-release) to
  # vulkanImageCUDA, which fails CMake outright in the sandbox, and v13.3
  # onwards reorganise Samples/ into cpp/ and python/, which nixpkgs' prePatch
  # and installPhase are written against.
  cudaPackages = prev.cudaPackages_13_4.overrideScope (
    _: prevCuda: {
      cuda-samples = prevCuda.cuda-samples.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          (final.fetchpatch {
            name = "cuda-samples-cuda-std-tuple.patch";
            url = "https://github.com/NVIDIA/cuda-samples/commit/6c4d183ba30202520b66e7b524f47780bb1f3c36.patch";
            hash = "sha256-kV6efwOXZN/hU1pyE28d/zWu6oolxNbiJbK65QdGVkg=";
          })
        ];
      });
    }
  );

  # opencv_contrib's videostab calls thrust::make_tuple without including
  # <thrust/tuple.h>, which CCCL stopped pulling in transitively as of CUDA
  # 13.2, so the CUDA build fails. Backport the upstream fix
  # (opencv/opencv_contrib#4130). Drop this once nixpkgs carries it
  # (NixOS/nixpkgs#566302).
  opencv4 = prev.opencv4.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (final.fetchpatch {
        name = "videostab-add-missing-include-to-fix-build-failure";
        url = "https://github.com/opencv/opencv_contrib/commit/054007b78c8288ef2fd040e77dc0cf2e45f70c15.patch";
        stripLen = 2;
        extraPrefix = "opencv_contrib/";
        hash = "sha256-vDW6kfDmwPB/tTurkDXuvViXrzXYV4njjDN6kLoIvJ4=";
      })
    ];
  });

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # compressed-tensors imports psutil in its offload code, and upstream's
      # setup.py lists it in install_requires, but the nixpkgs derivation
      # doesn't propagate it.
      compressed-tensors = python-prev.compressed-tensors.overridePythonAttrs (oldAttrs: {
        dependencies = (oldAttrs.dependencies or [ ]) ++ [ python-final.psutil ];
      });

      # MAGMA is in torch's closure purely to provide GPU LAPACK, and nixpkgs
      # adds it unconditionally under cudaSupport -- a ~3500-object CUDA build,
      # about half an hour on the Spark. On CUDA 13.4 cuSOLVER covers the paths
      # that matter: torch compiles its MAGMA torch.linalg.eig path only when
      # CUSOLVER_VERSION < 11702, its MAGMA triangular_solve path is ROCm-only,
      # and lu_factor's default backend falls through to cuSOLVER/cuBLAS when
      # MAGMA is absent.
      #
      # What this gives up: torch.backends.cuda.preferred_linalg_library("magma")
      # now raises rather than selecting a backend, and batched non-square
      # lu_factor loses the MAGMA path that torch's own comment calls the
      # fastest. Note 14 call sites guard on AT_MAGMA_ENABLED and only the four
      # above were read, so treat the rest of torch.linalg on GPU as untested
      # here.
      #
      # USE_MAGMA=0 on its own saves no build time, because nixpkgs would still
      # realise magma as a declared input, so drop it from buildInputs too.
      torch = python-prev.torch.overrideAttrs (oldAttrs: {
        env = (oldAttrs.env or { }) // {
          USE_MAGMA = "0";
        };
        buildInputs = prev.lib.filter
          (
            drv: drv == null || (drv.pname or drv.name or "") != "magma"
          )
          oldAttrs.buildInputs;
      });

      # cupy 14.1.1 wraps its SpGEAM stub declarations in
      # "#ifndef CUSPARSE_SPGEAM_ALG_DEFAULT", assuming a cuSPARSE that
      # provides SpGEAM would define that name as a macro. cuSPARSE 12.8 (CUDA
      # 13.4) declares it as an enum member instead, so the guard stays true:
      # cupy defines both algorithm names as macros and forward-declares the
      # descriptor as void*, and the real header's enum body then expands to
      # "{ 0 = 0, 1 = 1 }". Include the header and test its version instead.
      # cupy 14.2.0 drops the stubs altogether, so this goes when nixpkgs
      # moves off 14.1.1 (NixOS/nixpkgs#566291).
      cupy = python-prev.cupy.overridePythonAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace cupy_backends/cuda/libs/cusparse.pxd \
            --replace-fail \
              '#ifndef CUSPARSE_SPGEAM_ALG_DEFAULT' \
              '#include <cusparse.h>''\n    #if CUSPARSE_VERSION < 12806'
        '';
      });

      # CUDA 13 moved the crt/ headers out of cuda_nvcc into a separate
      # cuda_crt package, and nixpkgs' bitsandbytes doesn't include it.
      bitsandbytes = python-prev.bitsandbytes.overridePythonAttrs (oldAttrs: {
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
          # cuda_compat is not an alternative here, as it is unavailable on
          # linux-sbsa. cudla_linux.pyx is deliberately left alone --
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
          # affects the passthru.gpuCheck variant. Carried over from 13_3.nix.
          disabledTests = [
            # Requires GPU discovery support not available in the test environment
            "test_discover_gpus"

            # sysfs cpu topology is not available in the sandbox
            "test_device_get_cpu_affinity_within_scope"
            "test_device_get_memory_affinity"

            # Requires the nvidia_fs kernel module (GPUDirect Storage)
            "test_buf_register_already_registered"
            "test_buf_register_host_memory"
            "test_buf_register_invalid_flags"
            "test_buf_register_large_buffer"
            "test_buf_register_multiple_buffers"
            "test_buf_register_simple"
            "test_get_bar_size_in_kb"
            "test_get_parameter_min_max_value"
            "test_set_parameter_posix_pool_slab_array"
            "test_set_stats_level"
            "test_stats_start_stop"
          ];
        });

      # Upstream marks vllm broken under CUDA, with no reason given
      # (NixOS/nixpkgs#553566), pending the bump in NixOS/nixpkgs#549327. The
      # 0.24.0 build succeeds here with CUDA 13.4, so unbreak it.
      #
      # It is also marked bad on aarch64-linux, but the reason given there
      # ("could not find git for clone of arm_compute-populate") belongs to
      # the CPU backend, which pulls in oneDNN and Arm Compute Library. A CUDA
      # build never touches either.
      #
      # Drop this once the upstream bump lands.
      vllm = python-prev.vllm.overrideAttrs (old: {
        meta = old.meta // {
          broken = false;
          badPlatforms = prev.lib.filter (p: p != "aarch64-linux") (old.meta.badPlatforms or [ ]);
        };
      });
    })
  ];
}
