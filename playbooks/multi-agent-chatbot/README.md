# Build and deploy a multi-agent chatbot playbook

Deploy a multi-agent chatbot system using LLM orchestration on the DGX Spark.

## Usage

```bash
nix develop .#multi-agent-chatbot
multi-agent-chatbot-start
```

On first run the launcher clones the
[NVIDIA DGX Spark playbooks](https://github.com/NVIDIA/dgx-spark-playbooks)
repository and downloads approximately 114 GB of model weights. Subsequent
launches skip the download.

The frontend is served at <http://localhost:3000> and the backend API at
<http://localhost:8000>.

### Architecture

The multi-agent chatbot uses specialised agents for different tasks:

- **Router Agent** -- directs queries to the appropriate specialist
- **Code Agent** -- handles programming questions (DeepSeek Coder 6.7B)
- **Knowledge Agent** -- answers factual queries (GPT-OSS 120B)
- **Creative Agent** -- generates creative content
- **Vision Agent** -- processes images (Qwen2.5-VL 7B)
- **Embedding** -- vector search via Qwen3-Embedding 4B

Supporting services include PostgreSQL, Milvus (vector database with etcd and
MinIO), and a custom llama.cpp server for GGUF model inference.

### Remote access

If connecting over SSH, forward the required ports:

```bash
ssh -L 3000:localhost:3000 -L 8000:localhost:8000 user@dgx-spark
```

### Cleanup

```bash
podman-compose -f docker-compose.yml -f docker-compose-models.yml down
podman volume rm "$(basename "$PWD")_postgres_data"
```

DGX Spark hardware with an NVIDIA GPU is required. This demo uses
approximately 120 GB of the 128 GB available on a DGX Spark.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/multi-agent-chatbot/instructions)
- [NVIDIA DGX Spark Playbooks Repository](https://github.com/NVIDIA/dgx-spark-playbooks)
