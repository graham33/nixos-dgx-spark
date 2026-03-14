{ mkShell
, podman
, curl
, jq
, nixglhost
}:

let
  containerImage = "nvcr.io/nvidia/pytorch:25.11-py3";
in
mkShell {
  packages = [
    nixglhost
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
    echo "  multimodal-inference-container            — pull image, launch container, and install Flux deps"
    echo ""
    echo "Inside the container, generate an image:"
    echo "  export HF_TOKEN=<your-token>"
    echo "  python3 demo_txt2img_flux.py \"a photo of a cat\" --hf-token=\$HF_TOKEN --bf16 --download-onnx-models"
    echo ""

    multimodal-inference-container() {
      echo "Pulling container image ${containerImage}..."
      ${podman}/bin/podman pull ${containerImage}

      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        ${containerImage} /bin/bash -c '
          set -e
          export TRT_OSSPATH=/workspace/TensorRT
          git clone https://github.com/NVIDIA/TensorRT.git -b main --single-branch "$TRT_OSSPATH"
          cd "$TRT_OSSPATH/demo/Diffusion"
          pip install nvidia-modelopt[torch,onnx]
          sed -i "/^nvidia-modelopt\[.*\]=.*/d" requirements.txt
          pip3 install -r requirements.txt
          pip install onnxconverter_common
          python setup.py flux --skip-tensorrt
          echo ""
          echo "=== Flux dependencies installed ==="
          echo "To generate an image, run:"
          echo "  export HF_TOKEN=<your-token>"
          echo "  python3 demo_txt2img_flux.py \"a beautiful photograph of Mt. Fuji\" --hf-token=\$HF_TOKEN --bf16 --download-onnx-models"
          echo ""
          exec /bin/bash
        '
    }

    export -f multimodal-inference-container
  '';
}
