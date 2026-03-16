{ mkShell
, comfyuiPackages
, comfyuiModels
, nixglhost
}:

mkShell {
  packages = [
    nixglhost
    (comfyuiPackages.comfyui.override {
      withModels = [ comfyuiModels.sd15-fp16 ];
    })
  ];

  shellHook = ''
    if [ ! -f /etc/NIXOS ]; then
      comfyui() { nixglhost comfyui "$@"; }
      export -f comfyui
    fi
  '';
}
