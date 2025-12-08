# CUDA 12.9 overlay
# - Upgrades cudaPackages_12 to CUDA 12.9.1 (cudaPackages_12_9)
final: prev: {
  cudaPackages_12 = prev.cudaPackages_12_9;
}
