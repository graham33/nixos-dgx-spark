# CUDA 13 overlay
# - Switches to cudaPackages_13
# - Patches magma for CUDA 13 version detection
# - Marks torch as not broken (upstream marks it broken for CUDA 13)
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      torch = python-prev.torch.overridePythonAttrs (oldAttrs: {
        meta = oldAttrs.meta // { broken = false; };
      });
    })
  ];

  cudaPackages = prev.cudaPackages_13.overrideScope (cudaFinal: cudaPrev: {
    # Fix cuda_cccl to include cccl subdirectory for CUTLASS compatibility
    # The source has include/cccl/cuda/std but the build strips the cccl prefix
    cuda_cccl = cudaPrev.cuda_cccl.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        # Create cccl symlink for newer CUTLASS versions that expect cccl/ prefix
        mkdir -p $out/include/cccl
        ln -sf $out/include/cuda $out/include/cccl/cuda
        ln -sf $out/include/cub $out/include/cccl/cub
        ln -sf $out/include/thrust $out/include/cccl/thrust
        ln -sf $out/include/nv $out/include/cccl/nv
      '';
    });
  });

  magma = prev.magma.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (final.fetchpatch {
        name = "magma-fix-cuda-version-detection.patch";
        url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
        hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU=";
      })
    ];
  });
}
