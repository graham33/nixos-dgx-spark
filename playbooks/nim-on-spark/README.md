# NIM on Spark Playbook

NVIDIA NIM (NVIDIA Inference Microservices) provides optimised, containerised
inference for LLMs on the DGX Spark.

## Usage

```bash
nix develop /path/to/playbooks#nim-on-spark
nim-start
```

OpenAI-compatible API at **http://localhost:8000/v1**.

### Environment Variables

- `NGC_API_KEY` (required): Your NVIDIA NGC API key from https://org.ngc.nvidia.com/
- `NIM_CACHE` (optional): Path for NIM model cache (default: `~/.cache/nim`)
- `NIM_WORKSPACE` (optional): Path for NIM workspace (default: `~/.local/share/nim/workspace`)

### Testing

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta/llama-3.1-8b-instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 256
  }' | jq
```

### NIM Advantages

- Pre-optimised TensorRT-LLM engines
- Production-ready serving with health checks
- OpenAI-compatible API
- Automatic GPU memory management

> **Note:** DGX Spark hardware with NVIDIA GPU is required. An NVIDIA NGC API
> key is required for pulling NIM containers.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nim-llm/instructions)
- [NVIDIA NIM Documentation](https://docs.nvidia.com/nim/)
