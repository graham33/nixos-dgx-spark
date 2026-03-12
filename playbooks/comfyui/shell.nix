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
}
