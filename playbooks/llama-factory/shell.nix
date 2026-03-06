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
    echo "=== LLaMA Factory Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/llama-factory/instructions"
    echo ""
    echo "Start LLaMA Factory with WebUI:"
    echo "  nix run .#llama-factory-container"
    echo ""
    echo "Access the WebUI at: http://localhost:7860"
  '';
}
