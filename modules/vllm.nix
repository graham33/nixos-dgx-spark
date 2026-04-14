{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.vllm;

  instanceModule = { name, config, ... }: {
    options = {
      enable = lib.mkEnableOption "this vLLM instance" // { default = true; };

      model = lib.mkOption {
        type = lib.types.str;
        description = "HuggingFace model ID or local path to serve.";
        example = "Intel/Qwen3.5-122B-A10B-int4-AutoRound";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8000;
        description = "Port for the OpenAI-compatible API server.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Host address to bind to.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Start this instance automatically on boot.";
      };

      gpuMemoryUtilization = lib.mkOption {
        type = lib.types.float;
        default = 0.76;
        description = ''
          Fraction of GPU memory to use for model weights and KV cache.
          On DGX Spark, 0.76 is the safe ceiling — above 0.84 causes
          swap thrash during model loading.
        '';
      };

      maxModelLen = lib.mkOption {
        type = lib.types.int;
        default = 65536;
        description = "Maximum context length (tokens).";
      };

      toolCallParser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Tool/function calling parser. When set, enables
          --enable-auto-tool-choice. Common values: "qwen3_coder",
          "gemma4", "hermes", "llama3_json".
        '';
        example = "qwen3_coder";
      };

      reasoningParser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Reasoning/thinking parser for chain-of-thought models.
          Common values: "qwen3", "deepseek_r1".
        '';
        example = "qwen3";
      };

      enforceEager = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Disable CUDA graph compilation and use eager execution.
          Required on DGX Spark (SM121) to avoid illegal instruction
          crashes with some quantization formats.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional command-line arguments for vllm serve.";
      };
    };
  };

  enabledInstances = lib.filterAttrs (_: inst: inst.enable) cfg.instances;
  instanceNames = lib.attrNames enabledInstances;

  mkService = name: inst:
    let
      otherNames = lib.filter (n: n != name) instanceNames;
      args = [
        "serve"
        inst.model
        "--host"
        inst.host
        "--port"
        (toString inst.port)
        "--gpu-memory-utilization"
        (toString inst.gpuMemoryUtilization)
        "--max-model-len"
        (toString inst.maxModelLen)
      ]
      ++ lib.optionals (inst.toolCallParser != null) [
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        inst.toolCallParser
      ]
      ++ lib.optionals (inst.reasoningParser != null) [
        "--reasoning-parser"
        inst.reasoningParser
      ]
      ++ lib.optionals inst.enforceEager [ "--enforce-eager" ]
      ++ inst.extraArgs;
    in
    {
      description = "vLLM inference server (${name}: ${inst.model})";
      after = [ "network.target" ];
      wantedBy = lib.mkIf inst.autoStart [ "multi-user.target" ];
      # Ensure only one vLLM instance runs at a time — they share the GPU.
      conflicts = map (n: "vllm-${n}.service") otherNames;

      serviceConfig = {
        # Drop page caches so vLLM sees the full unified memory pool.
        ExecStartPre = [
          "+${pkgs.bash}/bin/bash -c 'sync; echo 3 > /proc/sys/vm/drop_caches'"
        ];
        ExecStart = "${pkgs.vllm}/bin/vllm ${lib.escapeShellArgs args}";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
in
{
  options.services.vllm = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = ''
        Named vLLM inference server instances. Each instance becomes a
        systemd service `vllm-<name>.service`. Instances declare mutual
        conflicts so only one can run at a time on a single-GPU host.
      '';
    };
  };

  config = lib.mkIf (enabledInstances != { }) {
    systemd.services = lib.mapAttrs'
      (name: inst: lib.nameValuePair "vllm-${name}" (mkService name inst))
      enabledInstances;
  };
}
