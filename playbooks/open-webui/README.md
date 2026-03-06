# Open WebUI with Ollama Playbook

Open WebUI provides a ChatGPT-like browser interface for interacting with local LLMs
via Ollama on the NVIDIA DGX Spark.

## Usage

```bash
nix develop .#open-webui
open-webui-start
```

Then open your browser at **http://localhost:8080**.

### What This Runs

The container bundles both Open WebUI and Ollama, providing:

- A browser-based chat interface (port 8080)
- Ollama API (port 11434)
- Automatic GPU acceleration via `--device nvidia.com/gpu=all`
- Persistent storage for application data and downloaded models

### Pulling Models

Once the container is running, pull a model via the Ollama API:

```bash
curl http://localhost:11434/api/pull -d '{"name": "llama3.2"}'
```

Or use the WebUI's model manager at **Settings → Models**.

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU-accelerated
> inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/open-webui/instructions)
- [Open WebUI Documentation](https://docs.openwebui.com/)
- [Ollama Documentation](https://ollama.com/docs)
