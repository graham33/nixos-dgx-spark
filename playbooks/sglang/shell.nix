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
    echo "  sglang-start"
    echo ""
    echo "OpenAI-compatible API at: http://localhost:${sglangPort}/v1"
    echo ""
    echo "Test the server:"
    echo "  curl http://localhost:${sglangPort}/v1/models | jq"
    echo ""

    # Create sglang-start command
    sglang-start() {
      echo "Starting SGLang inference server with meta-llama/Llama-3.1-8B-Instruct..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        --network host \
        -v /tmp:/tmp \
        lmsysorg/sglang:spark \
        python3 -m sglang.launch_server \
          --model-path meta-llama/Llama-3.1-8B-Instruct \
          --host 0.0.0.0 \
          --port ${sglangPort} \
          --trust-remote-code \
          --tp 1 \
          --attention-backend flashinfer \
          --mem-fraction-static 0.75
    }

    export -f sglang-start
  '';
}
