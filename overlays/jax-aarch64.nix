# Disable JAX test suite on aarch64-linux.
#
# 64 out of ~30,000 tests fail with:
#   JaxRuntimeError: INTERNAL: Failed to materialize symbols
#   LLVM compilation error: Cannot allocate memory
#
# These are LLVM JIT memory exhaustion errors in the Nix sandbox, not
# functional bugs.  They affect Pallas and shape-polymorphism tests that
# exercise heavy LLVM code-generation paths.  The failures are
# reproducible on nixbuild.net but not on machines with more RAM/swap
# available to the sandbox.
#
# Upstream tracking:
#   https://github.com/NixOS/nixpkgs/issues/445824
#   https://github.com/NixOS/nixpkgs/issues/376961
final: prev: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isAarch64 {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (python-final: python-prev: {
      jax = python-prev.jax.overridePythonAttrs (old: {
        doCheck = false;
      });
    })
  ];
}
