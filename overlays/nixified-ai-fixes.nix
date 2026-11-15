# Fixes for the nixified-ai overlays: its comfyuiPackages set and its
# python3Packages scope.
#
# Must be applied *after* nixified-ai.overlays.comfyui, which defines
# comfyuiPackages and extends python3Packages with overrideScope -- an
# override in fixes.nix (which runs earlier) would just be clobbered.
final: prev: {
  comfyuiPackages = prev.comfyuiPackages // {
    # nixified-ai's own comfy-aimdo builds its static funchook with the
    # distorm disassembler, which is x86-only, so it fails to compile on
    # aarch64. nixpkgs packages the same version by running upstream's
    # scripts/build-linux-aimdo.sh, which picks capstone on arm64, so use
    # that. Drop this once nixified-ai handles aarch64.
    comfy-aimdo = final.python3Packages.comfy-aimdo;

    # nixified-ai pins the wrong hash for the aarch64 comfy_angle wheel; this
    # one matches PyPI's published sha256 (28956a7d...). The x86_64 hash is
    # correct. Drop this once nixified-ai fixes it.
    comfy-angle = prev.comfyuiPackages.comfy-angle.overridePythonAttrs (
      final.lib.optionalAttrs final.stdenv.hostPlatform.isAarch64 {
        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/65/1d/87298bb1935268c63bc27d24487b5e40f58e74da3138e122123ce6b052cb/comfy_angle-0.1.0-py3-none-manylinux_2_28_aarch64.whl";
          hash = "sha256-KJVqfXjbrjtB+DiIpeCIQ6x0e3Zj+WdMKWFCdNPxfBU=";
        };
      }
    );
  };

  python3Packages = prev.python3Packages.overrideScope (
    _: pyprev: {
      # nixified-ai patches transformers to make the flash_attn lookup in
      # import_utils.py tolerant of a missing distribution, but transformers
      # has done exactly that itself since 5.15 (every flash_attn lookup in
      # import_utils.py reads .get("flash_attn", [])). The patch's
      # --replace-fail therefore aborts the build, breaking comfyui.
      # nixified-ai doesn't see this itself because its own nixpkgs pin still
      # has an older transformers; we only hit it through inputs.follows.
      #
      # Relax just that one call to --replace-quiet: a no-op while upstream
      # carries the fix, and still correct if nixified-ai's patch becomes
      # load-bearing again. Drop this once nixified-ai removes the patch.
      transformers = pyprev.transformers.overridePythonAttrs (old: {
        postPatch = builtins.replaceStrings
          [ "--replace-fail 'PACKAGE_DISTRIBUTION_MAPPING[\"flash_attn\"]'" ]
          [ "--replace-quiet 'PACKAGE_DISTRIBUTION_MAPPING[\"flash_attn\"]'" ]
          (old.postPatch or "");
      });
    }
  );
}
