# vLLM dependencies overlay
# Fixes tensorflow dependency issues in transformers and outlines
# Fixes xgrammar badPlatforms for aarch64-linux
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # Fix xgrammar badPlatforms for aarch64-linux and upgrade to 0.1.27
      xgrammar = python-prev.xgrammar.overridePythonAttrs (oldAttrs: {
        version = "0.1.27";
        src = prev.fetchFromGitHub {
          owner = "mlc-ai";
          repo = "xgrammar";
          rev = "v0.1.27";
          hash = "sha256-XwMSYgXoNKglN772vtrqFOtq//trpIH9Oi/hk++Tf84=";
        };
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ final.dlpack ];
        # Disable -Werror to avoid compilation failures with gcc 14
        NIX_CFLAGS_COMPILE = (oldAttrs.NIX_CFLAGS_COMPILE or "") + " -Wno-error";
        # Disable test that requires network access to huggingface.co and slow tests
        disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [
          "tests/python/test_structural_tag_converter.py"
          "tests/python/test_serialization.py"
        ];
        meta = oldAttrs.meta // {
          badPlatforms = [ ];
        };
      });

      # Override transformers to not include tensorflow in optional dependencies
      transformers = python-prev.transformers.overridePythonAttrs (oldAttrs: {
        optional-dependencies = prev.lib.mapAttrs
          (name: deps:
            if name == "tf" then
              prev.lib.filter (dep: !(prev.lib.hasInfix "tensorflow" (dep.pname or ""))) deps
            else deps
          )
          (oldAttrs.optional-dependencies or { });
      });

      # Override outlines to not include tensorflow in tests
      outlines = python-prev.outlines.overridePythonAttrs (oldAttrs: {
        doCheck = false;
        nativeCheckInputs = [ ];
      });
    })
  ];
}
