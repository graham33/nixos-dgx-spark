{ mkShell
, curl
, fetchurl
, jq
}:

let
  lmsPort = "1234";

  lmStudioVersion = "0.4.6-1";

  # LM Studio is distributed as an AppImage for Linux (aarch64).
  # The versioned URL follows the pattern:
  #   https://installers.lmstudio.ai/linux/{arch}/{version}/LM-Studio-{version}-{arch}.AppImage
  # A stable redirect to the latest version is also available at:
  #   https://lmstudio.ai/download/latest/linux/arm64
  # We pin to a specific version for reproducibility; update lmStudioVersion
  # and hash when upgrading.
  lmStudioAppImage = fetchurl {
    url = "https://installers.lmstudio.ai/linux/arm64/${lmStudioVersion}/LM-Studio-${lmStudioVersion}-arm64.AppImage";
    hash = "sha256-Nrvp0syo7POGE/KRpykDYck6oaLIsNTp/v81avrsypU=";
  };

  # Client helper scripts from the lmstudio-ai/docs repository, fetched as
  # Nix derivations rather than requiring curl at runtime.
  lmStudioDocsRev = "main";
  lmStudioDocsBase = "https://raw.githubusercontent.com/lmstudio-ai/docs/${lmStudioDocsRev}/_assets/nvidia-spark-playbook";

  sparkClientJs = fetchurl {
    url = "${lmStudioDocsBase}/js/run.js";
    hash = "sha256-lU1vIav2K2IuXeC1VnZo48/YKrGiDamjI47sb4nP8Lc=";
  };

  sparkClientPy = fetchurl {
    url = "${lmStudioDocsBase}/py/run.py";
    hash = "sha256-QPHGxjtAZyLeE5TOpgJs5FoVnEPaGJaXVI7Tdk+6+Ts=";
  };

  sparkClientSh = fetchurl {
    url = "${lmStudioDocsBase}/bash/run.sh";
    hash = "sha256-BDPrl/66RMzXkC7jtCEt/7JGCI7rT4SbyXrQFjEBsUM=";
  };
in
mkShell {
  packages = [
    curl
    jq
  ];

  shellHook = ''
    echo "=== LM Studio on DGX Spark Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/lm-studio/instructions"
    echo ""
    echo "Step 1: Install LM Studio ${lmStudioVersion}:"
    echo "  lms-install"
    echo ""
    echo "Step 2: Start the API server:"
    echo "  lms server start --bind 0.0.0.0 --port ${lmsPort}"
    echo ""
    echo "Step 3: Download and load a model:"
    echo "  lms get openai/gpt-oss-120b"
    echo "  lms load openai/gpt-oss-120b"
    echo ""
    echo "Test from your laptop:"
    echo "  lms-test-server <SPARK_IP>"
    echo "  lms-test-chat <SPARK_IP>"
    echo ""
    echo "Copy NVIDIA client example scripts to current directory:"
    echo "  lms-get-client-scripts"
    echo ""

    # Install LM Studio by placing the AppImage from the Nix store into
    # ~/.lmstudio/bin and extracting the bundled lms CLI.
    lms-install() {
      local install_dir="$HOME/.lmstudio/bin"
      local appimage="$install_dir/LM-Studio.AppImage"
      echo "Installing LM Studio ${lmStudioVersion} from Nix store..."
      mkdir -p "$install_dir"
      cp ${lmStudioAppImage} "$appimage"
      chmod +x "$appimage"
      "$appimage" --appimage-extract-and-run lms-extract \
        --extract-dir "$install_dir/squashfs-root" 2>/dev/null \
        || "$appimage" --appimage-extract --target "$install_dir/squashfs-root" 2>/dev/null \
        || true
      echo "LM Studio AppImage installed to $appimage"
      echo "Add ~/.lmstudio/bin to your PATH to use lms:"
      echo "  export PATH=\"\$HOME/.lmstudio/bin:\$PATH\""
    }

    # Copy NVIDIA client example scripts (fetched via Nix) to the current directory.
    lms-get-client-scripts() {
      echo "Copying LM Studio client example scripts..."
      cp ${sparkClientJs} ./run.js && chmod +w ./run.js
      cp ${sparkClientPy} ./run.py && chmod +w ./run.py
      cp ${sparkClientSh} ./run.sh && chmod +wx ./run.sh
      echo "Copied run.js, run.py, and run.sh."
      echo "Replace {SPARK_LOCAL_IP} with your DGX Spark IP address."
    }

    # Test server connectivity
    lms-test-server() {
      local host="''${1:-localhost}"
      echo "Testing LM Studio server at $host:${lmsPort}..."
      curl -s "http://$host:${lmsPort}/api/v1/models" | jq
    }

    # Test chat completion
    lms-test-chat() {
      local host="''${1:-localhost}"
      local model="''${2:-openai/gpt-oss-120b}"
      echo "Testing chat completion with $model at $host:${lmsPort}..."
      curl -s "http://$host:${lmsPort}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"$model\",
          \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}],
          \"max_tokens\": 200
        }" | jq -r '.choices[0].message.content'
    }

    export -f lms-install
    export -f lms-get-client-scripts
    export -f lms-test-server
    export -f lms-test-chat
  '';
}
