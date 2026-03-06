# Live VLM WebUI Playbook

Real-time Vision-Language Model WebUI on the DGX Spark for live camera
analysis using Ollama.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#live-vlm-webui
   ```

2. Start the Ollama backend and WebUI:

   ```bash
   live-vlm-start
   ```

3. Open **https://localhost:8090** in your browser to access the interface.

> **Note:** HTTPS is required for browser webcam access. The WebUI generates
> self-signed certificates automatically.

## Available Commands

- `live-vlm-start` — Start Ollama and the Live VLM WebUI containers (pulls
  `gemma3:4b` on first run)
- `live-vlm-pull-model [model]` — Pull an additional vision model (defaults to
  `gemma3:4b`)
- `live-vlm-models` — List models available in Ollama
- `live-vlm-stop` — Stop all Live VLM containers

## Supported Models

| Model             | Size | Use Case                      |
| ----------------- | ---- | ----------------------------- |
| `gemma3:4b`       | 4B   | Lightweight vision tasks      |
| `llama3.2-vision` | 11B  | General vision-language tasks |
| `qwen2.5-vl`      | 7B   | Balanced quality and speed    |

## Camera Access

The WebUI accesses your camera through the browser (WebRTC), so no device
passthrough is needed in the container.

> **Note:** DGX Spark hardware with NVIDIA GPU is required for real-time
> inference.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/live-vlm-webui/instructions)
- [live-vlm-webui on GitHub](https://github.com/NVIDIA-AI-IOT/live-vlm-webui)
