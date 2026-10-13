# Forces full evaluation and instantiation of the real dgx-spark
# configuration (including the custom kernel derivation) without building
# anything. Catches nixpkgs bumps breaking modules/dgx-spark.nix cheaply.
# The 64K-page variant (dgx-spark-64k) is evaluated too, and so is a
# gpuClockCap config, checking the service locks the clock to the cap.
{ pkgs, self }:
let
  system = self.nixosConfigurations.dgx-spark;
  system64k = self.nixosConfigurations.dgx-spark-64k;
  systemCapped = system.extendModules {
    modules = [{ hardware.dgx-spark.gpuClockCap = 2300; }];
  };
  capService = systemCapped.config.systemd.services.gpu-clock-cap;
in
assert !(system.config.systemd.services ? gpu-clock-cap);
assert pkgs.lib.hasSuffix "--lock-gpu-clocks=0,2300" capService.serviceConfig.ExecStart;
assert builtins.elem "nvidia-persistenced.service" capService.partOf;
pkgs.runCommand "dgx-spark-eval"
{
  drvPath = builtins.unsafeDiscardStringContext
    system.config.system.build.toplevel.drvPath;
  drvPath64k = builtins.unsafeDiscardStringContext
    system64k.config.system.build.toplevel.drvPath;
  drvPathCapped = builtins.unsafeDiscardStringContext
    systemCapped.config.system.build.toplevel.drvPath;
} ''
  echo "$drvPath" > $out
  echo "$drvPath64k" >> $out
  echo "$drvPathCapped" >> $out
''
