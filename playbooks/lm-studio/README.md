# LM Studio on DGX Spark Playbook

LM Studio provides a CLI (`lms`) for running local LLMs with GPU acceleration on the
NVIDIA DGX Spark. Unlike container-based playbooks, LM Studio is installed natively via
its installer script.

## Prerequisites

- DGX Spark with ARM64 processor and Blackwell GPU
- At least 65 GB GPU memory (70 GB+ recommended)
- At least 65 GB storage space (70 GB+ recommended)

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#lm-studio
   ```

2. Install the LM Studio CLI on your Spark:

   ```bash
   curl -fsSL https://lmstudio.ai/install.sh | bash
   ```

   Follow the terminal instructions to add `lms` to your PATH.

3. Start the API server:

   ```bash
   lms server start --bind 0.0.0.0 --port 1234
   ```

4. Download and load a model:

   ```bash
   lms get openai/gpt-oss-120b
   lms load openai/gpt-oss-120b
   ```

5. Test from your laptop:

   ```bash
   lms-test-server <SPARK_IP>
   lms-test-chat <SPARK_IP>
   ```

## Available Commands

- `lms-test-server <host>` -- Test server connectivity and list loaded models
- `lms-test-chat <host> [model]` -- Send a test chat completion request

## Client Helper Scripts

NVIDIA provides helper scripts for connecting from your laptop:

```bash
# JavaScript
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/js/run.js

# Python
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/py/run.py

# Bash
curl -L -O https://raw.githubusercontent.com/lmstudio-ai/docs/main/_assets/nvidia-spark-playbook/bash/run.sh
```

Replace `<SPARK_IP>` in the downloaded script, then run it.

## Cleanup

```bash
# Remove downloaded models
rm -rf ~/.lmstudio/models/

# Uninstall LM Studio CLI
rm -rf ~/.lmstudio/llmster
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/lm-studio/instructions)
- [LM Studio Documentation](https://lmstudio.ai/docs)
