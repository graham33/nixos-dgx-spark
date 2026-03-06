{ mkShell
, podman
, curl
, jq
}:
let
  sglangPort = "30000";
in
mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== SGLang for Inference Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/sglang/instructions"
    echo ""
    echo "SGLang is a fast LLM serving framework with an OpenAI-compatible API."
    echo ""
    echo "Start the SGLang server:"
    echo "  nix run .#sglang-container"
    echo ""
    echo "OpenAI-compatible API at: http://localhost:${sglangPort}/v1"
    echo ""
    echo "Test the server:"
    echo "  curl http://localhost:${sglangPort}/v1/models | jq"
  '';
}
