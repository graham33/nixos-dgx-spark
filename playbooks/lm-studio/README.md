# LM Studio on DGX Spark Playbook

LM Studio provides a CLI (`lms`) for running local LLMs with GPU acceleration on the
NVIDIA DGX Spark. LM Studio is installed from a versioned AppImage fetched by Nix.

## Prerequisites

- DGX Spark with ARM64 processor and Blackwell GPU
- At least 65 GB GPU memory (70 GB+ recommended)
- At least 65 GB storage space (70 GB+ recommended)

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#lm-studio
   ```

2. Install LM Studio on your Spark:

   ```bash
   lms-install
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

- `lms-install` -- Install LM Studio from the Nix store (AppImage fetched at eval time)
- `lms-test-server <host>` -- Test server connectivity and list loaded models
- `lms-test-chat <host> [model]` -- Send a test chat completion request

## Client Helper Scripts

NVIDIA provides helper scripts for connecting from your laptop. The devshell fetches
these from the [lmstudio-ai/docs](https://github.com/lmstudio-ai/docs) repository as
Nix derivations. Copy them to your current directory with:

```bash
lms-get-client-scripts
```

This copies `run.js` (JavaScript), `run.py` (Python), and `run.sh` (Bash) to the
current directory. Replace `{SPARK_LOCAL_IP}` in the script with your DGX Spark's
IP address, then run it.

## Upgrading LM Studio

The AppImage version is pinned in `shell.nix`. To upgrade, update `lmStudioVersion`
and the `hash` field (use the new hash from `nix-prefetch-url`).

## Cleanup

```bash
# Remove downloaded models
rm -rf ~/.lmstudio/models/

# Uninstall LM Studio
rm -rf ~/.lmstudio/bin/
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/lm-studio/instructions)
- [LM Studio Documentation](https://lmstudio.ai/docs)
