final: prev: {
  cudaPackages = prev.cudaPackages_13;

  magma = prev.magma.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (final.fetchpatch {
        name = "magma-fix-cuda-version-detection.patch";
        url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
        hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU="; # Replace with actual hash
      })
    ];
  });

  python3 = prev.python3.override {
    packageOverrides = pythonSelf: pythonSuper: {
      torch = pythonSuper.torch.overridePythonAttrs (oldAttrs: {
        meta = oldAttrs.meta // {
          broken = false;
        };
      });
    };
  };
}
