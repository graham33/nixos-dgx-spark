# Forces full evaluation and instantiation of the real dgx-spark
# configuration (including the custom kernel derivation) without building
# anything. Catches nixpkgs bumps breaking modules/dgx-spark.nix cheaply.
# The 64K-page variant (dgx-spark-64k) is evaluated too.
{ pkgs, self }:
let
  system = self.nixosConfigurations.dgx-spark;
  system64k = self.nixosConfigurations.dgx-spark-64k;
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
