# SGLang for Inference Playbook

SGLang is a fast LLM serving framework that provides an OpenAI-compatible API
for efficient inference on the NVIDIA DGX Spark.

## Usage

```bash
nix develop /path/to/playbooks#sglang
sglang-start
```

The server runs on port 30000.

### API Access

```bash
# List models
curl http://localhost:30000/v1/models | jq

# Chat completion
curl http://localhost:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 512
  }' | jq
```

### SGLang vs vLLM

- **RadixAttention** for KV-cache reuse across requests
- Faster throughput for batch inference
- Efficient structured output generation

> **Note:** DGX Spark hardware with NVIDIA GPU is required for inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/sglang/instructions)
- [SGLang Documentation](https://sgl-project.github.io/)
