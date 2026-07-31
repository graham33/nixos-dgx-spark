# Forces full evaluation and instantiation of the real dgx-spark
# configuration (including the custom kernel derivation) without building
# anything. Catches nixpkgs bumps breaking modules/dgx-spark.nix cheaply.
{ pkgs, self }:
pkgs.runCommand "dgx-spark-eval"
{
  drvPath = builtins.unsafeDiscardStringContext
    self.nixosConfigurations.dgx-spark.config.system.build.toplevel.drvPath;
} ''
  echo "$drvPath" > $out
''
