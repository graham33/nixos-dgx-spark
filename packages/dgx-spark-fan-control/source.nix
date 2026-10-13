# Shared by the CLI (default.nix) and the kernel module (kmod.nix), which
# must come from the same commit: the CLI checks the driver's cooling-device
# contract (type name and state count).
{ fetchFromGitHub }:

{
  version = "0.1.3-unstable-2026-09-08";

  src = fetchFromGitHub {
    owner = "christopherowen";
    repo = "dgx-spark-fan-control";
    rev = "deb2ea155f6698b769ff4977dea2119e3b32f460";
    hash = "sha256-Dz4/LT52Zmrr6aLjlBNbkEu4lo47ztqsjTMqnJz11bk=";
  };
}
