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

  cudaPackages = prev.cudaPackages_13;

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
