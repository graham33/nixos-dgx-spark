# Forces full evaluation and instantiation of the real dgx-spark
# configuration (including the custom kernel derivation) without building
# anything. Catches nixpkgs bumps breaking modules/dgx-spark.nix cheaply.
# The 64K-page kernel variant is evaluated too, since nothing else builds it.
{ pkgs, self }:
let
  system = self.nixosConfigurations.dgx-spark;
  system64k = system.extendModules {
    modules = [{ hardware.dgx-spark.use64kKernel = true; }];
  };
in
pkgs.runCommand "dgx-spark-eval"
{
  drvPath = builtins.unsafeDiscardStringContext
    system.config.system.build.toplevel.drvPath;
  drvPath64k = builtins.unsafeDiscardStringContext
    system64k.config.system.build.toplevel.drvPath;
} ''
  echo "$drvPath" > $out
  echo "$drvPath64k" >> $out
''
