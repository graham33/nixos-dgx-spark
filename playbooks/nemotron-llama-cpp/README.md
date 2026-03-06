# Nemotron-3-Nano with llama.cpp Playbook

Run NVIDIA Nemotron-3-Nano in GGUF format using llama.cpp with CUDA
acceleration on the DGX Spark.

## Usage

### Nix-native (recommended)

```bash
nix develop .#nemotron-llama-cpp
```

Download a Nemotron GGUF model, then start the server:

```bash
llama-server -m nemotron-3-nano.gguf --port 8080 -ngl 99
```

### Container

```bash
nix run .#nemotron-llama-cpp-container
```

### API

The server exposes an OpenAI-compatible API at **http://localhost:8080/v1**.

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 256
  }'
```

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU-accelerated
> inference. The `-ngl 99` flag offloads all layers to GPU.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nemotron/instructions)
