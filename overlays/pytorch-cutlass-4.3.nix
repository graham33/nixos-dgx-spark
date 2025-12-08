# PyTorch CUTLASS 4.3.2 overlay
# Replaces PyTorch's vendored CUTLASS 4.1 with 4.3.2 for Blackwell (sm121a) support
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      torch = python-prev.torch.overridePythonAttrs (oldAttrs: {
        postUnpack = (oldAttrs.postUnpack or "") + ''
          echo "Replacing vendored CUTLASS with 4.3.2 for Blackwell support..."
          rm -rf $sourceRoot/third_party/cutlass
          cp -r ${final.fetchFromGitHub {
            owner = "NVIDIA";
            repo = "cutlass";
            rev = "v4.3.2";
            hash = "sha256-lThCPuRwn2Pa+2lPugylTMRnMtGqwZYKbl/1Amw8tZk=";
          }} $sourceRoot/third_party/cutlass
        '';
      });
    })
  ];
}
