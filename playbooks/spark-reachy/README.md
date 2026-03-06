# Spark & Reachy Photo Booth Playbook

An AI-powered photo booth combining DGX Spark with a Reachy Mini robot by
Pollen Robotics. A multi-modal agent built with the NeMo Agent Toolkit uses a
ReAct loop powered by TensorRT-LLM to drive the robot and generate images.

> **Hardware requirement:** This playbook requires a
> [Reachy Mini](https://www.pollen-robotics.com/) robot (or Reachy Mini Lite) in
> addition to NVIDIA DGX Spark. It will not function without the robot hardware.

## Prerequisites

- NVIDIA DGX Spark with Docker/Podman and NVIDIA Container Toolkit
- Reachy Mini or Reachy Mini Lite robot
- USB-C cable for robot connection
- Monitor, keyboard, and mouse
- NVIDIA NGC API key (prefix `nvapi-…`)
- Hugging Face token (prefix `hf_…`) with access to gated repositories
  - Accept the
    [FLUX.1-Kontext-dev](https://huggingface.co/black-forest-labs/FLUX.1-Kontext-dev)
    licence on Hugging Face before running

## Usage

Enter the development shell:

```bash
nix develop .#spark-reachy
```

Then follow the steps printed in the shell, or see below.

### Step-by-step

1. Clone the photo booth repository and `cd` into it.
2. Copy `.env.example` to `.env` and fill in your NGC and Hugging Face tokens.
3. Connect and power on the Reachy Mini; verify with `lsusb`.
4. Log in to the NGC container registry:
   ```bash
   podman login nvcr.io
   ```
5. Build and launch the services (first run takes 30 minutes to 2 hours):
   ```bash
   podman-compose up --build -d
   ```
6. Open the web UI at <http://127.0.0.1:3001>.

### Services

The application comprises twelve microservices: agent, animation compositor,
animation database, camera, interaction manager, metrics, remote control, robot
controller, speech-to-text, text-to-speech, tracker, and UI server.

### AI models

| Purpose            | Model                                    |
| ------------------ | ---------------------------------------- |
| LLM                | `openai/gpt-oss-20b` (TensorRT-LLM)      |
| Image generation   | `black-forest-labs/FLUX.1-Kontext-dev`   |
| Speech recognition | `nvidia/riva-parakeet-ctc-1.1B`          |
| Speech synthesis   | `hexgrad/Kokoro-82M`                     |
| Vision / tracking  | `facebookresearch/detectron2`, ByteTrack |

## Time estimate

Approximately 2 hours including hardware setup, container builds, and model
downloads.

## References

- [NVIDIA instructions](https://build.nvidia.com/spark/spark-reachy-photo-booth/instructions)
- [Pollen Robotics — Reachy Mini](https://www.pollen-robotics.com/)
