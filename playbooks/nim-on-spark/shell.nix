{ mkShell
, podman
, curl
, jq
, nixglhost
}:

mkShell {
  packages = [
    nixglhost
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== NIM on Spark Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nim-llm/instructions"
    echo ""
    echo "NVIDIA NIM provides optimised inference microservices."
    echo ""
    echo "Start a NIM container:"
    echo "  nim-start"
    echo ""
    echo "OpenAI-compatible API at: http://localhost:8000/v1"
    echo ""

    nim-start() {
      if [ -z "$NGC_API_KEY" ]; then
        echo "Error: NGC_API_KEY environment variable is not set."
        echo "Get your API key from https://org.ngc.nvidia.com/"
        return 1
      fi

      NIM_CACHE="''${NIM_CACHE:-$HOME/.cache/nim}"
      NIM_WORKSPACE="''${NIM_WORKSPACE:-$HOME/.local/share/nim/workspace}"
      mkdir -p "$NIM_CACHE" "$NIM_WORKSPACE"

      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=16g \
        --network host \
        -e NGC_API_KEY \
        -v "$NIM_CACHE":/opt/nim/.cache \
        -v "$NIM_WORKSPACE":/opt/nim/workspace \
        nvcr.io/nim/meta/llama-3.1-8b-instruct-dgx-spark:latest
    }

    export -f nim-start
  '';
}
