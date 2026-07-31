# Evaluation-only test of the vllm module: renders the systemd units with
# a stubbed vllm package (the real one is a huge CUDA build) and asserts
# on the generated unit definitions. Nothing is built beyond a trivial
# derivation.
{ nixpkgs, system, pkgs }:
let
  inherit (nixpkgs) lib;

  stubbed = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/vllm.nix
      {
        nixpkgs.overlays = [
          (final: prev: { vllm = final.writeShellScriptBin "vllm" "exit 0"; })
        ];
        system.stateVersion = "25.11";
        services.vllm.instances = {
          coder = {
            model = "some/model";
            toolCallParser = "qwen3_coder";
            autoStart = true;
          };
          chat.model = "other/model";
        };
      }
    ];
  };

  units = stubbed.config.systemd.services;

  # Discard string context so the stub package never becomes a build
  # dependency of this check.
  execStart = builtins.unsafeDiscardStringContext units.vllm-coder.serviceConfig.ExecStart;

  ok =
    assert lib.assertMsg (units ? vllm-coder && units ? vllm-chat)
      "expected vllm-coder and vllm-chat services to be generated";
    assert lib.assertMsg (units.vllm-coder.conflicts == [ "vllm-chat.service" ])
      "vllm-coder should conflict with vllm-chat";
    assert lib.assertMsg (units.vllm-chat.conflicts == [ "vllm-coder.service" ])
      "vllm-chat should conflict with vllm-coder";
    assert lib.assertMsg (units.vllm-coder.wantedBy == [ "multi-user.target" ])
      "autoStart instance should be wanted by multi-user.target";
    assert lib.assertMsg (units.vllm-chat.wantedBy == [ ])
      "non-autoStart instance should not be wanted by any target";
    assert lib.assertMsg (lib.hasInfix "--enable-auto-tool-choice" execStart)
      "toolCallParser should enable --enable-auto-tool-choice";
    assert lib.assertMsg (lib.hasInfix "--tool-call-parser" execStart && lib.hasInfix "qwen3_coder" execStart)
      "toolCallParser value should be passed to --tool-call-parser";
    assert lib.assertMsg (lib.hasInfix "--enforce-eager" execStart)
      "enforceEager default should pass --enforce-eager";
    assert lib.assertMsg (lib.hasInfix "--gpu-memory-utilization 0.76" execStart)
      "gpuMemoryUtilization default should be 0.76";
    true;
in
assert ok;
pkgs.runCommand "vllm-units-test" { } "touch $out"
