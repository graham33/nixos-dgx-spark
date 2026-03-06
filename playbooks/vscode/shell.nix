{ mkShell
, openssh
, vscode
}:

mkShell {
  packages = [
    openssh
    vscode
  ];

  shellHook = ''
    echo "=== VS Code on DGX Spark Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/vscode/instructions"
    echo ""
    echo "Use VS Code Remote SSH to connect to your DGX Spark."
    echo "Install the Remote-SSH extension, then:"
    echo "  code --remote ssh-remote+user@dgxspark.local ."
  '';
}
