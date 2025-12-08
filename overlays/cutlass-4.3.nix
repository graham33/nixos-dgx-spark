# CUTLASS 4.3.2 overlay
# Upgrades cutlass to version 4.3.2 with Blackwell (sm121a) support
final: prev: {
  _cuda = prev._cuda.extend (
    _: prevAttrs: {
      extensions = prevAttrs.extensions ++ [
        (cudaFinal: cudaPrev: {
          cutlass = cudaPrev.cutlass.overrideAttrs (oldAttrs: {
            version = "4.3.2";
            src = final.fetchFromGitHub {
              owner = "NVIDIA";
              repo = "cutlass";
              rev = "v4.3.2";
              hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Placeholder - will be computed by Nix
            };
          });
        })
      ];
    }
  );
}
