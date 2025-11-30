# Stable Diffusion models for ComfyUI
# Used by devShells.comfyui with withModels
final: prev: {
  comfyuiModels = {
    # Stable Diffusion 1.5 (fp16, ~2GB)
    # From NVIDIA DGX Spark playbook: https://build.nvidia.com/spark/comfy-ui/instructions
    sd15-fp16 = final.fetchResource {
      name = "v1-5-pruned-emaonly-fp16.safetensors";
      url = "https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors";
      hash = "sha256-6UdqE3KM112Cefbsi611OmahlXyjdaFGTcY7N9tuORY=";
      passthru.comfyui.installPaths = [ "checkpoints" ];
    };
  };
}
