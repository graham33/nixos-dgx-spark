# Text to Knowledge Graph Playbook

Build knowledge graphs from unstructured text using GPU-accelerated LLM inference on the DGX Spark. The pipeline uses Ollama for local LLM inference, ArangoDB as the graph database, and a Next.js frontend for document management and graph visualisation.

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#txt2kg
   ```

2. Start the services:

   ```bash
   txt2kg-start
   ```

3. Pull a model into Ollama:

   ```bash
   txt2kg-pull-model llama3.1:8b
   ```

4. Open the web interface at `http://localhost:3001`

## Available Commands

- `txt2kg-start` — Start ArangoDB + Ollama + frontend
- `txt2kg-start-vllm` — Start with Neo4j + vLLM backend (GPU-optimised)
- `txt2kg-stop` — Stop all services
- `txt2kg-pull-model [model]` — Pull a model into Ollama (default: `llama3.1:8b`)
- `txt2kg-test` — Check Ollama is responding

## Services

| Service    | URL                      | Description                       |
| ---------- | ------------------------ | --------------------------------- |
| Web UI     | `http://localhost:3001`  | Document upload and graph browser |
| ArangoDB   | `http://localhost:8529`  | Graph database web console        |
| Ollama API | `http://localhost:11434` | LLM inference endpoint            |

## Pipeline

1. Upload or paste text documents via the web UI
2. The LLM extracts entities and relations as subject-predicate-object triples
3. Triples are stored in ArangoDB as a knowledge graph
4. Query and visualise the graph interactively

## Larger Models

The DGX Spark unified memory architecture supports models up to 70B parameters. Pull a larger model for improved accuracy:

```bash
txt2kg-pull-model llama3.1:70b
```

> **Note:** DGX Spark hardware with an NVIDIA GPU is required for LLM inference.

## Reference

Based on the NVIDIA DGX Spark playbook: https://build.nvidia.com/spark/txt2kg/instructions
