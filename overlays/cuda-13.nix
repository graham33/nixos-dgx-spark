# CUDA 13 overlay
# - Switches to cudaPackages_13_2
# - Marks torch as not broken (upstream marks it broken for CUDA 13)
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      torch = python-prev.torch.overridePythonAttrs (oldAttrs: {
        meta = oldAttrs.meta // { broken = false; };
      });
    })
  ];

  cudaPackages =
    let
      base = prev.cudaPackages_13_2.overrideScope (cudaFinal: cudaPrev: {
        # Bump NCCL to v2.28.9-1 (nixpkgs has v2.28.7-1)
        nccl = cudaPrev.nccl.overrideAttrs (oldAttrs: {
          version = "2.28.9-1";
          src = prev.fetchFromGitHub {
            owner = "NVIDIA";
            repo = "nccl";
            rev = "v2.28.9-1";
            hash = "sha256-1nNLcS/F0HsGbYf327TLX+ZVI13YcrrhpLqbGVuml2g=";
          };
        });
      });
    in
    base // { inherit (prev.cudaPackages_13_2) override; };

}
