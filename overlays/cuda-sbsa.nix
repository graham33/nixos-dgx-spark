# Disable cuda_compat for linux-sbsa (aarch64 servers)
# cuda_compat has src = null for linux-sbsa even though meta.platforms claims support
final: prev:
if prev.stdenv.hostPlatform.system == "aarch64-linux" then {
  _cuda = prev._cuda.extend (
    _: prevAttrs: {
      extensions = prevAttrs.extensions ++ [ (_: _: { cuda_compat = null; }) ];
    }
  );
}
else { }
