# Forces full evaluation and instantiation of the real dgx-spark
# configuration (including the custom kernel derivation) without building
# anything. Catches nixpkgs bumps breaking modules/dgx-spark.nix cheaply.
# The 64K-page variant (dgx-spark-64k) is evaluated too, and so is a config
# with the optional features on: gpuClockCap, checking the service locks the
# clock to the cap, and fanControl with its curve, checking the driver is
# installed and loaded and the curve service runs.
{ pkgs, self }:
let
  system = self.nixosConfigurations.dgx-spark;
  system64k = self.nixosConfigurations.dgx-spark-64k;
  systemOptional = system.extendModules {
    modules = [{
      hardware.dgx-spark.gpuClockCap = 2300;
      hardware.dgx-spark.fanControl = {
        enable = true;
        curve.enable = true;
      };
    }];
  };
  inherit (systemOptional.config.systemd) services;
  capService = services.gpu-clock-cap;
  fanService = services.dgx-fan-control;
in
assert !(system.config.systemd.services ? gpu-clock-cap);
assert !(system.config.systemd.services ? dgx-fan-control);
assert pkgs.lib.hasSuffix "--lock-gpu-clocks=0,2300" capService.serviceConfig.ExecStart;
assert builtins.elem "nvidia-persistenced.service" capService.partOf;
assert builtins.elem "dgx_ec_fan_control" systemOptional.config.boot.kernelModules;
assert builtins.any (p: p.pname or "" == "dgx-spark-fan-control-kmod")
  systemOptional.config.boot.extraModulePackages;
assert pkgs.lib.hasSuffix "/bin/dgx-fan-control daemon" fanService.serviceConfig.ExecStart;
pkgs.runCommand "dgx-spark-eval"
{
  drvPath = builtins.unsafeDiscardStringContext
    system.config.system.build.toplevel.drvPath;
  drvPath64k = builtins.unsafeDiscardStringContext
    system64k.config.system.build.toplevel.drvPath;
  drvPathOptional = builtins.unsafeDiscardStringContext
    systemOptional.config.system.build.toplevel.drvPath;
} ''
  echo "$drvPath" > $out
  echo "$drvPath64k" >> $out
  echo "$drvPathOptional" >> $out
''
