# Video Search and Summarisation Agent Playbook

GPU-accelerated video search and summarisation using NVIDIA's VSS blueprint.

## Prerequisites

- An NVIDIA GPU with sufficient VRAM, driver 580.126.09+ and CUDA 13.0
- NGC API key — set one up at <https://org.ngc.nvidia.com/setup/api-key> and then log in with `podman login nvcr.io`
- Accept the [Cosmos-Reason2-8B](https://huggingface.co/nvidia/Cosmos-Reason2-8B) model terms on Hugging Face

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#video-search-agent
   ```

2. Log in to NGC:

   ```bash
   podman login nvcr.io
   ```

3. Start the VSS Event Reviewer (fully local):

   ```bash
   vss-start
   ```

4. Access the UIs:
   - **CV UI** (video upload and processing): http://localhost:7862
   - **Alert Inspector UI** (VLM results review): http://localhost:7860

## Pipeline

1. **Ingest** — Upload and process video files
2. **Detect** — Run CV event detection on video frames
3. **Analyse** — Review detected events with the local VLM (Cosmos-Reason2-8B)
4. **Search** — Query videos using natural language
5. **Summarise** — Generate text summaries of video content

## Containers

The VSS Event Reviewer deploys eight containers:

| Container                     | Purpose              |
| ----------------------------- | -------------------- |
| `nv-cv-event-detector-ui`     | CV upload UI         |
| `nv-cv-event-detector` (sbsa) | CV event detection   |
| `nginx`                       | Reverse proxy        |
| `vss-alert-inspector-ui`      | Alert review UI      |
| `alert-bridge`                | Alert routing        |
| `vss-engine` (sbsa)           | Core VSS engine      |
| `vst-storage`                 | Video storage        |
| `redis-stack-server`          | Vector store (Redis) |

## Cleanup

```bash
IS_SBSA=1 ALERT_REVIEW_MEDIA_BASE_DIR=/tmp/alert-media-dir podman-compose down
podman network rm vss-shared-network
rm -rf /tmp/alert-media-dir
```

> **Note:** An NVIDIA GPU with sufficient VRAM is required for all inference
> workloads.

## Reference

Based on the NVIDIA DGX Spark playbook: https://build.nvidia.com/spark/vss/instructions
