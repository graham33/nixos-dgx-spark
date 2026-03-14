{ mkShell
, fetchFromGitHub
, nixglhost
, podman
, podman-compose
}:

let
  sparkReachySrc = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "spark-reachy-photo-booth";
    rev = "26f47db54cd2220c56bfed0c0da3507714c6a7e6";
    hash = "sha256-wdmAnAfY9N1EoN/1ZVWp+vq2tt0OttbGc2Yhms2o3nU=";
  };
in
mkShell {
  packages = [
    nixglhost
    podman
    podman-compose
  ];

  shellHook = ''
    echo "=== Spark & Reachy Photo Booth Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/spark-reachy-photo-booth/instructions"
    echo ""
    echo "HARDWARE REQUIRED: Reachy Mini (or Reachy Mini Lite) robot + DGX Spark"
    echo ""
    echo "Quick start:"
    echo "  1. cd ${sparkReachySrc}"
    echo "  2. Copy .env.example to .env and add your NGC + Hugging Face tokens"
    echo "  3. Connect the Reachy Mini via USB-C and verify with: lsusb"
    echo "  4. Log in to NGC: podman login nvcr.io"
    echo "  5. Launch: podman-compose up --build -d"
    echo "  6. Open http://127.0.0.1:3001"
    echo ""
    echo "See playbooks/spark-reachy/README.md for full details."
  '';
}
