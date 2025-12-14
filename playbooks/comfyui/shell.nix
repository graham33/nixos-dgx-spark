{ pkgs }:

pkgs.mkShell {
  packages = [
    (pkgs.comfyuiPackages.comfyui.override {
      withModels = [ pkgs.comfyuiModels.sd15-fp16 ];
    })
  ];
}
