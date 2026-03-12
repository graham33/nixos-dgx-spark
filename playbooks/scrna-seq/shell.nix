{ mkShell
, podman
, nixglhost
}:

mkShell {
  packages = [
    nixglhost
    podman
  ];

  shellHook = ''
    echo "=== Single-cell RNA Sequencing Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/single-cell/instructions"
    echo ""
    echo "Start the RAPIDS notebook environment:"
    echo "  scrna-seq-start"
    echo ""
    echo "Access JupyterLab at: http://localhost:8888"
    echo ""

    # Launch the RAPIDS single-cell RNA sequencing notebook container
    scrna-seq-start() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
        -p 8888:8888 -p 8787:8787 -p 8786:8786 -p 8501:8501 -p 8050:8050 \
        -v "$PWD":/workspace \
        nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13
    }

    export -f scrna-seq-start
  '';
}
