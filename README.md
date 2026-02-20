# Agentic Data Stack

The open-source stack for ClickHouse's suite of agentic analytic tools — your chat, your models, your data.  
Powered by [ClickHouse](https://clickhouse.com), [LibreChat](https://librechat.ai), and [Langfuse](https://langfuse.com).

> Learn more at [clickhouse.ai](https://clickhouse.ai)

## Overview

This project runs a fully self-hosted agentic analytics environment with Docker Compose. It connects a chat UI (LibreChat) to your data (ClickHouse) via MCP, with full LLM observability (Langfuse) — all in a single `docker compose up` command.

### What's included

| Component | Purpose | Port |
|---|---|---|
| **LibreChat** | Modern Chat UI with multi-model / provider support (OpenAI, Anthropic, Google) | `3080` |
| **ClickHouse MCP** | MCP server that gives agents access to ClickHouse | `8000` |
| **Langfuse** | LLM observability — traces, evals, prompt management | `3000` |
| **ClickHouse** | World's fastest analytical database | `8123` |
| **PostgreSQL** | Transactional database for Langfuse | `5432` |
| **MongoDB** | Transactional database for LibreChat | `27017` |
| **MinIO** | S3-compatible object storage | `9090` |
| **Redis** | Caching and queue | `6379` |
| **Meilisearch** | Full-text search for LibreChat | `7700` |
| **pgvector** | Vector database for RAG | `5433` |
| **RAG API** | Retrieval-augmented generation service for LibreChat | `8001` |

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2+

### 1. Generate credentials

```bash
./scripts/generate-env.sh
```

This is your fastest way to get started with the Agentic Data Stack. It creates a `.env` file with randomly generated passwords, keys, and secrets for all services. You can customize the initial settings with environment variables before running:

```bash
USER_EMAIL="you@example.com" USER_PASSWORD="supersecret" USER_NAME="YourName" ./scripts/generate-env.sh
```

### 2. Configure API keys

Edit your `.env` and set LLM providers, models, and their API keys, or leave them as `user_provided` to let users enter their own keys in the LibreChat UI (learn more on how to configure your LibreChat instance at https://librechat.ai/docs):

```
ANTHROPIC_API_KEY=user_provided
GOOGLE_KEY=user_provided
OPENAI_API_KEY=user_provided
```

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Access the services

- **LibreChat** — [http://localhost:3080](http://localhost:3080)
- **Langfuse** — [http://localhost:3000](http://localhost:3000)
- **MinIO Console** — [http://localhost:9091](http://localhost:9091) (Find credentials in `.env` under MINIO_ROOT_* fields)

An admin user is created automatically on first startup using the credentials from your `.env` file.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────┐
│  LibreChat   │────▶│  ClickHouse MCP  │────▶│  ClickHouse  │
│  (Chat UI)   │     │  (MCP Server)    │     │  (Analytics)  │
└──────┬───────┘     └──────────────────┘     └──────────────┘
       │
       │ traces
       ▼
┌──────────────┐
│   Langfuse   │
│ (Observability)│
└──────────────┘
```

LibreChat connects to ClickHouse through the MCP server, allowing AI agents to query and analyze your data. All LLM interactions are traced in Langfuse for observability, evaluation, and prompt management.

## Scripts

| Script | Description |
|---|---|
| `scripts/generate-env.sh` | Generate `.env` with random credentials |
| `scripts/reset-all.sh` | Stop all containers and wipe all data/volumes |
| `scripts/create-librechat-user.sh` | Manually create a LibreChat admin user |
| `scripts/init-librechat-user.sh` | Auto-init user on container startup (used internally) |

## Configuration

- **LibreChat** — `librechat.yaml` configures endpoints, MCP servers, and agent capabilities
- **Environment** — `.env` holds all credentials and service configuration (see `.env.example` for reference)
- **Docker** — `docker-compose.yml` includes the three compose files:
  - `langfuse-compose.yml` — Langfuse, ClickHouse, PostgreSQL, Redis, MinIO
  - `clickhouse-mcp-compose.yml` — ClickHouse MCP server
  - `librechat-compose.yml` — LibreChat, MongoDB, Meilisearch, pgvector, RAG API

## Reset Everything

To tear down all containers and delete all data:

```bash
./scripts/reset-all.sh
```

Then regenerate credentials and start fresh:

```bash
./scripts/generate-env.sh
docker compose up -d
```

## Links

- [clickhouse.ai](http://clickhouse.ai) — Project homepage
- [Documentation](https://clickhouse.com/docs/use-cases/AI/MCP/librechat) — Full setup guide for adding ClickHouse MCP to LibreChat
- [ClickHouse MCP](https://github.com/ClickHouse/mcp-clickhouse) — MCP server for ClickHouse
- [LibreChat](https://github.com/danny-avila/LibreChat) — Chat UI
- [Langfuse](https://langfuse.com) — LLM observability
