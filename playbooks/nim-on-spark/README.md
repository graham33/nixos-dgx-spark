# NIM on Spark Playbook

NVIDIA NIM (NVIDIA Inference Microservices) provides optimised, containerised
inference for LLMs on the DGX Spark.

## Usage

```bash
nix run .#nim-on-spark-container
```

OpenAI-compatible API at **http://localhost:8000/v1**.

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
> key may be required for pulling NIM containers.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nim-llm/instructions)
- [NVIDIA NIM Documentation](https://docs.nvidia.com/nim/)
