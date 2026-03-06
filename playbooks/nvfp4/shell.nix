{ mkShell
, podman
, curl
, jq
}:

mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== NVFP4 Quantisation Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nvfp4-quantization/instructions"
    echo ""
    echo "NVFP4 quantisation reduces model size with minimal quality loss."
    echo ""
    echo "Start the quantisation environment:"
    echo "  nix run .#nvfp4-container"
  '';
}
