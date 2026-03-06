# LLaMA Factory Playbook

LLaMA Factory is a unified fine-tuning framework for LLMs, supporting LoRA,
QLoRA, and full fine-tuning with a Gradio WebUI on the DGX Spark.

## Usage

```bash
nix run .#llama-factory-container
```

Access the WebUI at **http://localhost:7860**.

### Fine-tuning Methods

| Method | VRAM Required | Speed |
|---|---|---|
| LoRA | Low | Fast |
| QLoRA | Very low | Moderate |
| Full | High | Slow |

### Supported Models

LLaMA, Mistral, Qwen, ChatGLM, and many more. See the
[LLaMA Factory repository](https://github.com/hiyouga/LLaMA-Factory) for the
full list.

> **Note:** DGX Spark hardware with NVIDIA GPU is required for training.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/llama-factory/instructions)
- [LLaMA Factory on GitHub](https://github.com/hiyouga/LLaMA-Factory)
