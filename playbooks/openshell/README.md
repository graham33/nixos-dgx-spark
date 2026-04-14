# OpenShell playbook

Secure long-running AI agents with OpenShell on DGX Spark. This playbook
deploys [OpenClaw](https://docs.openclaw.ai/) inside an
[OpenShell](https://pypi.org/project/openshell/) sandbox with kernel-level
isolation, routing inference to a local Ollama model.

## Prerequisites

OpenShell runs a k3s cluster inside a container and requires rootful podman.
The DGX Spark NixOS module configures this automatically:

- `virtualisation.podman.dockerSocket.enable` -- rootful socket at
  `/run/docker.sock`
- `networking.firewall.trustedInterfaces = [ "podman+" ]` -- allows containers
  to reach host services like Ollama
- `hardware.nvidia-container-toolkit.enable` -- GPU access from containers

## Usage

```bash
nix develop .#openshell
```

Follow the numbered steps printed on entry. The setup is interactive and takes
20-30 minutes (plus model download time).

```bash
openshell-gpu-check        # 1. Verify GPU access via podman
openshell-ollama-start     # 2. Start Ollama (run in a separate terminal)
openshell-gateway-start    # 3. Deploy the OpenShell gateway
openshell-provider-create  # 4. Create local Ollama provider
openshell-inference-set    # 5. Configure inference routing
openshell-sandbox-create   # 6. Launch OpenClaw in a sandbox
```

### OpenClaw onboarding wizard

The sandbox creation launches an interactive wizard. Select these options:

1. **Model/auth provider**: Custom Provider
2. **API Base URL**: `https://inference.local/v1`
3. **API key**: `ollama`
4. **Endpoint compatibility**: OpenAI-compatible
5. **Model ID**: `nemotron-3-nano` (or your model from step 5)
6. **Channel**: Skip for now
7. **Search provider**: Skip for now
8. **Skills**: No
9. **Hooks**: Skip for now

### Ollama model selection

| Available memory | Suggested model       | Size  |
| ---------------- | --------------------- | ----- |
| 25-48 GB         | nemotron-3-nano       | ~24GB |
| 48-80 GB         | gpt-oss:120b          | ~65GB |
| 128 GB           | nemotron-3-super:120b | ~86GB |

Pull a model before starting the sandbox:

```bash
ollama pull nemotron-3-nano
```

### Remote access

If connecting over SSH, forward port 18789 for the OpenClaw web UI:

```bash
ssh -L 18789:localhost:18789 user@dgx-spark
```

Then open `http://127.0.0.1:18789/?token=<your-token>` in your browser.

### Environment variables

- `OPENSHELL_HOST_IP` -- override auto-detected host for provider creation
  (default: `host.docker.internal`)

### Cleanup

```bash
openshell-cleanup          # Remove sandbox, provider, stop gateway
openshell gateway destroy  # Permanently destroy the gateway
ollama rm <model-name>     # Remove downloaded models
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/openshell)
- [NVIDIA DGX Spark Playbooks Repository](https://github.com/NVIDIA/dgx-spark-playbooks/tree/main/nvidia/openshell)
- [OpenShell Documentation](https://pypi.org/project/openshell/)
