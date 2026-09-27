# Fixes for the nixified-ai overlays' python3Packages scope.
#
# Must be applied *after* nixified-ai.overlays.comfyui, which extends the
# set with python3Packages.overrideScope -- an override in fixes.nix (which
# runs earlier) would just be clobbered.
final: prev: {
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
