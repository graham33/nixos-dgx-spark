final: prev: {
  # Override the EOL linux_6_17 throw with a working kernel package
  # This allows us to continue using NVIDIA's maintained 6.17 kernel branch
  # even though upstream kernel.org has marked 6.17 as EOL
  #
  # We use linux_latest as the base since it will always point to a supported kernel
  # The actual kernel source, version, and config will be completely overridden
  # in modules/dgx-spark.nix, so the base version is irrelevant
  linux_6_17 = prev.linux_latest;

  linuxPackages_6_17 = prev.linuxPackagesFor final.linux_6_17;
}
