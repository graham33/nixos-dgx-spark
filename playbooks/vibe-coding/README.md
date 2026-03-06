# Vibe Coding in VS Code Playbook

Vibe coding uses a local LLM running on the DGX Spark as an AI coding assistant in
VS Code, via the Continue.dev extension and Ollama.

## Usage

Start the Ollama backend:

```bash
nix run .#vibe-coding-container
```

This pulls and serves the `gpt-oss:120b` model (or `gpt-oss:20b` for less VRAM) via
Ollama on port 11434.

### VS Code Setup

1. Install the **Continue.dev** extension from the VS Code marketplace
2. Open the Continue configuration (`~/.continue/config.yaml`) and add:

   ```yaml
   models:
     - title: DGX Spark Local
       provider: ollama
       model: gpt-oss:120b
       apiBase: http://localhost:11434
   ```

3. Use `Ctrl+I` (or `Cmd+I`) to open the AI chat panel

### Models

| Model          | VRAM Required | Notes               |
| -------------- | ------------- | ------------------- |
| `gpt-oss:120b` | ~80 GB        | Full-quality model  |
| `gpt-oss:20b`  | ~20 GB        | Lighter alternative |

> **Note:** DGX Spark hardware with NVIDIA GPU is required for GPU-accelerated
> inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/vibe-coding/instructions)
- [Continue.dev Documentation](https://docs.continue.dev/)
- [Ollama Documentation](https://ollama.com/docs)
