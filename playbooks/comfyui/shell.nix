{ mkShell
, comfyuiPackages
, comfyuiModels
}:

mkShell {
  packages = [
    (comfyuiPackages.comfyui.override {
      withModels = [ comfyuiModels.sd15-fp16 ];
    })
  ];
}
