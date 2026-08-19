# 64K-page overrides for the NVIDIA DGX kernel.
#
# NVIDIA ships two arm64 flavours in NV-Kernels: `arm64-nvidia` (inheriting
# `arm64-generic`, 4K pages) and `arm64-nvidia-64k` (inheriting
# `arm64-generic-64k`, 64K pages). The generated terse config in
# `nvidia-dgx-spark-<version>.nix` is exported for the 4K flavour, so these
# are the deltas that turn it into the 64K one.
#
# The values come from the `arm64-generic-64k` column of
# `debian.master/config/annotations` in the NV-Kernels tree -- the nvidia
# annotations file itself carries no page-size overrides, so the flavour
# defaults stand. Only the symbols that are a genuine Kconfig choice are
# listed here: `PAGE_SHIFT`, `PAGE_SIZE_64KB`, `HAVE_PAGE_SIZE_64KB`,
# `THP_SWAP`, `ARCH_WANT_HUGE_PMD_SHARE` and the AArch32 emulation symbols
# (`ARMV8_DEPRECATED`, `SWP_EMULATION`, ...) are all selected or derived, so
# kconfig resolves them from the choices below.
#
# Re-check this list against the annotations file when bumping the NVIDIA
# kernel: `grep generic-64k debian.master/config/annotations`.
{ lib }:

with lib.kernel;

{
  # The page-size choice itself. ARM64_16K_PAGES is already `no` in the
  # generated config, so it needs no override here.
  ARM64_4K_PAGES = lib.mkForce no;
  ARM64_64K_PAGES = lib.mkForce yes;

  # 64K granule reaches 48-bit VA in three levels rather than four.
  # ARM64_VA_BITS stays at 48.
  PGTABLE_LEVELS = lib.mkForce (freeform "3");

  # Contiguous-PTE/PMD block sizes are granule-dependent.
  ARM64_CONT_PMD_SHIFT = lib.mkForce (freeform "5");
  ARM64_CONT_PTE_SHIFT = lib.mkForce (freeform "5");

  # AArch32 userspace is not supported on a 64K-granule kernel; the 32-bit
  # emulation and compat symbols fall out with it.
  COMPAT = lib.mkForce no;
  COMPAT_32BIT_TIME = lib.mkForce no;

  # mmap randomisation is bounded by the page size: the larger granule leaves
  # fewer bits to randomise. ARCH_MMAP_RND_COMPAT_BITS goes away with COMPAT.
  ARCH_MMAP_RND_BITS = lib.mkForce (freeform "29");
  ARCH_MMAP_RND_COMPAT_BITS = lib.mkForce unset;
}
