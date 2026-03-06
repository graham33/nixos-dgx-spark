{ mkShell
, podman
, curl
, jq
}:

let
  containerImage = "nvcr.io/nvidia/pytorch:25.11-py3";
in
mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== Multi-modal Inference Playbook ==="
    echo "Container: ${containerImage}"
    echo "Instructions: https://build.nvidia.com/spark/multi-modal-inference/instructions"
    echo ""
    echo "Commands:"
    echo "  multimodal-inference-container            — launch the container with GPU support"
    echo "  podman pull ${containerImage}             — pull the latest image"
    echo ""
    echo "Inside the container, clone TensorRT and run Diffusion demos:"
    echo "  export HF_TOKEN=<your-token>"
    echo "  git clone https://github.com/NVIDIA/TensorRT.git -b main --single-branch"
    echo "  cd TensorRT/demo/Diffusion"
    echo "  pip install -r requirements.txt"
    echo "  python3 demo_txt2img_flux.py \"a photo of a cat\" --hf-token=\$HF_TOKEN --bf16 --download-onnx-models"
    echo ""

    multimodal-inference-container() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        ${containerImage} /bin/bash
    }

    export -f multimodal-inference-container
  '';
}
