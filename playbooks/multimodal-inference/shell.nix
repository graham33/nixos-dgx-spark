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
    if [ ! -f /etc/NIXOS ]; then
      if [ ! -f "$HOME/.config/containers/policy.json" ] && [ ! -f /etc/containers/policy.json ]; then
        echo "ERROR: No container policy.json found. Podman will not be able to pull images."
        echo "Fix with: mkdir -p ~/.config/containers && cp ${../../containers/policy.json} ~/.config/containers/policy.json"
        return 1
      fi
      if [ ! -f "$HOME/.config/containers/registries.conf" ] && [ ! -f /etc/containers/registries.conf ]; then
        echo "ERROR: No registries.conf found. Podman will not be able to resolve short image names."
        echo "Fix with: mkdir -p ~/.config/containers && cp ${../../containers/registries.conf} ~/.config/containers/registries.conf"
        return 1
      fi
      if [ ! -f /etc/cdi/nvidia.yaml ] && [ ! -f /var/run/cdi/nvidia-container-toolkit.json ]; then
        echo "ERROR: No CDI spec found. Podman will not be able to access GPUs."
        echo "Fix with: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
        return 1
      fi
    fi

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
