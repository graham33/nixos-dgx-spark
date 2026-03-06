# RAG Application in AI Workbench Playbook

Retrieval-Augmented Generation (RAG) application using NVIDIA AI Workbench on
the DGX Spark. This playbook deploys an agentic RAG system that combines
document retrieval with live web search to provide grounded, accurate answers.

## Prerequisites

- **NVIDIA API Key** — generate at <https://org.ngc.nvidia.com/setup/api-keys>
  (select "Public API Endpoints" permissions)
- **Tavily API Key** — generate at <https://tavily.com>

Export both keys before entering the devshell:

```bash
export NVIDIA_API_KEY="your-nvidia-api-key"
export TAVILY_API_KEY="your-tavily-api-key"
```

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#rag-workbench
   ```

2. Clone the example repository:

   ```bash
   rag-clone
   ```

3. Start the RAG application:

   ```bash
   rag-start
   ```

4. In a separate terminal, test the application:

   ```bash
   nix develop .#rag-workbench
   rag-test "How do I add an integration in the CLI?"
   ```

5. Alternatively, open the Gradio web interface at `http://localhost:8080`

## Available Commands

- `rag-clone` — Clone the NVIDIA agentic RAG example repository
- `rag-start` — Start the RAG application container with GPU support
- `rag-test <query>` — Test the application with a query

## Components

- **AI Workbench Container** — `nvcr.io/nvidia/ai-workbench/python-basic:1.0.8`
- **Embedding Model** — NVIDIA API endpoints for document vectorisation
- **LLM Backend** — NVIDIA inference endpoints (with optional self-hosted
  support via Ollama or NIM)
- **Web Search** — Tavily integration for live web queries when retrieval
  context is insufficient

## How It Works

The agentic RAG system:

1. Routes queries with relevance checking
2. Retrieves context from uploaded documents
3. Falls back to web search when document context is insufficient
4. Evaluates response accuracy and iterates if needed

> **Note:** DGX Spark hardware with an NVIDIA GPU is required.

## Reference

Based on the NVIDIA DGX Spark playbook:
<https://build.nvidia.com/spark/rag-ai-workbench/instructions>

Source repository:
<https://github.com/NVIDIA/workbench-example-agentic-rag>
