{ stdenv, cudaPackages, autoAddDriverRunpath }:

stdenv.mkDerivation rec {
  pname = "cuda-debug";
  version = "1.0";
  src = ./.;
  buildInputs = [ cudaPackages.cuda_cudart ];
  nativeBuildInputs = [ cudaPackages.cuda_nvcc autoAddDriverRunpath ];

  inherit (cudaPackages.flags) cudaCapabilities;

  buildPhase = let
    # Generate CUBIN for each capability
    gencodeCubin = builtins.concatStringsSep " " (map (cap:
      "--generate-code arch=compute_${builtins.replaceStrings ["."] [""] cap},code=sm_${builtins.replaceStrings ["."] [""] cap}"
    ) cudaCapabilities);
    # Generate PTX for the highest capability (for forward compatibility)
    highestCap = builtins.elemAt cudaCapabilities ((builtins.length cudaCapabilities) - 1);
    gencodePtx = "--generate-code arch=compute_${builtins.replaceStrings ["."] [""] highestCap},code=compute_${builtins.replaceStrings ["."] [""] highestCap}";
  in ''
    echo "Compiling with: ${gencodeCubin} ${gencodePtx}"
    nvcc ${gencodeCubin} ${gencodePtx} -o cuda-debug cuda-debug.cu -L${cudaPackages.cuda_cudart}/lib/stubs -lcuda -lcudart
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp cuda-debug $out/bin/
  '';
}