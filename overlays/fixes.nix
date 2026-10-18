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

  # V8's SimdMemCopy, compiled only on arm64 with NEON, uses CHAR_BIT without
  # including <climits>. GCC 15's libstdc++ pulled it in transitively; GCC 16's
  # does not, so nodejs_26 fails to build on aarch64 (x86_64 never compiles
  # that path). llama-cpp builds its web UI with nodejs_latest, so this takes
  # the llama-cpp playbook down with it. V8 main still has the bare CHAR_BIT,
  # so there is no upstream patch to fetch yet.
  nodejs-slim_26 = prev.nodejs-slim_26.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace deps/v8/src/base/memcopy.h \
        --replace-fail '#include <stdlib.h>' $'#include <stdlib.h>\n\n#include <climits>'
    '';
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

      # torchaudio's suite runs ~2,200 CPU tests, taking anywhere from 3 to 59
      # minutes on the Spark depending on load, and is flaky:
      # test_decoder_inference_torchscript_consistency (Tacotron2) failed once
      # and passed on retry for the same derivation, its decoder stopping after
      # 1 frame instead of 300. vllm depends on torchaudio, so a flaky failure
      # here takes vllm and the system closure down with it.
      torchaudio = python-prev.torchaudio.overridePythonAttrs {
        doCheck = false;
      };

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
      #
      # vllm-flash-attn hard-codes FlashAttention-2's arch list as
      # "8.0+PTX", so on SM12x it ships only sm_80 cubins and compute_80
      # PTX, and every FA2 kernel is JIT-compiled by the driver. A driver can
      # only JIT PTX from a toolkit no newer than itself -- CUDA minor-version
      # compatibility does not cover PTX JIT -- so with CUDA 13.4 PTX (ISA
      # 9.4) on a CUDA 13.2 driver, vllm dies at engine init with
      # cudaErrorUnsupportedPtxVersion. Add 12.0 so the Spark gets sm_120
      # cubins, which run on its sm_121; other arch lists are unaffected.
      vllm = (python-prev.vllm.override {
        vllm-flash-attn = python-prev.vllm.vllm-flash-attn.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace CMakeLists.txt \
              --replace-fail \
                'cuda_archs_loose_intersection(FA2_ARCHS "8.0+PTX"' \
                'cuda_archs_loose_intersection(FA2_ARCHS "8.0+PTX;12.0"'
          '';
        });
      }).overrideAttrs (old: {
        meta = old.meta // {
          broken = false;
          badPlatforms = prev.lib.filter (p: p != "aarch64-linux") (old.meta.badPlatforms or [ ]);
        };
      });
    })
  ];
}
