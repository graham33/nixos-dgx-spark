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
      # 5.15.0 already does exactly that upstream (import_utils.py lines
      # 1176/1234/1245 all read .get("flash_attn", [])). The patch's
      # --replace-fail therefore aborts the build, breaking comfyui.
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
