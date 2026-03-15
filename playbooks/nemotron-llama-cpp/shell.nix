{ mkShell
, llama-cpp
, curl
, jq
, nixglhost
, python3Packages
}:

mkShell {
  packages = [
    nixglhost
    llama-cpp
    curl
    jq
    python3Packages.huggingface-hub
  ];

  shellHook = ''
    echo "=== Nemotron-3-Nano with llama.cpp Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nemotron/instructions"
    echo ""
    echo "This shell provides llama.cpp with CUDA support."
    echo ""
    echo "Download the model:"
    echo "  huggingface-cli download unsloth/Nemotron-3-Nano-30B-A3B-GGUF \\"
    echo "    Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf \\"
    echo "    --local-dir ~/models/nemotron3-gguf"
    echo ""
    echo "Start the server:"
    echo "  llama-server -m ~/models/nemotron3-gguf/Nemotron-3-Nano-30B-A3B-UD-Q8_K_XL.gguf --port 8080 -ngl 99"
    echo ""
    echo "API available at: http://localhost:8080/v1"
  '';
}
