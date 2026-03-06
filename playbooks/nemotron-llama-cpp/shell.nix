{ mkShell
, llama-cpp
, curl
, jq
}:

mkShell {
  packages = [
    llama-cpp
    curl
    jq
  ];

  shellHook = ''
    echo "=== Nemotron-3-Nano with llama.cpp Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nemotron/instructions"
    echo ""
    echo "This shell provides llama.cpp with CUDA support."
    echo ""
    echo "Download a Nemotron GGUF model, then:"
    echo "  llama-server -m model.gguf --port 8080 -ngl 99"
    echo ""
    echo "API available at: http://localhost:8080/v1"
  '';
}
