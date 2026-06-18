# LivChart Local AI Starter - Docker Setup for Local AI Data Analysis

LivChart Local AI Starter is the Docker-based setup repository for running LivChart Local AI Analytics with packaged LivChart builds and optional local AI model providers.

The official LivChart product website is https://livchart.com.

This starter is designed for local AI data analysis, private business intelligence, on-premise analytics, and local LLM analytics workflows where teams want to run LivChart with Docker on Linux, macOS, or Windows.

## What This Starter Does

During setup, the Docker build downloads the LivChart Linux package from the official LivChart GitHub Releases repository. The starter then adds the bundled configuration and sample LivChart DataSet database into Docker volumes.

This starter does not run PostgreSQL. The AI provider is selected during setup. Livaicloud is available as the default provider, and optional Ollama model choices are available for local AI workflows.

## About LivChart

LivChart AI Analytics is an AI-powered business intelligence and data analysis platform for dashboards, AI-generated charts, reports, DataStudio ETL workflows, and Analytics Studio workbooks.

LivChart Local AI Analytics brings the same analytics workflow to private and local AI environments. It supports local model providers such as Ollama and LM Studio for on-premise BI, local GPU inference, secure AI-assisted reporting, and privacy-focused analytics.

Official product website: https://livchart.com

Company website: https://livyazilim.com

Main release repository: https://github.com/livchart/livchart

## Who Should Use This Repository?

Use LivChart Local AI Starter if you want to:

- test LivChart with Docker before a wider deployment
- run local AI analytics with Ollama-backed models
- evaluate private AI dashboard and reporting workflows
- keep business analytics closer to local infrastructure
- deploy LivChart on Linux, macOS, or Windows with Docker Compose
- try Analytics Studio, dashboards, ETL workflows, and AI-assisted chart generation

## Requirements

- Linux: Docker Engine or Docker Desktop
- macOS: Docker Desktop
- Windows: Docker Desktop with WSL 2 backend
- Docker Compose v2
- A valid LivChart license or authentication key file

## License Key

Do not commit your license or authentication key to Git. For local runs, place it here:

```text
secrets/license.key
```

The filename can be different. The setup script automatically uses the first secrets/*.key file if secrets/license.key is not present. The secrets folder is ignored by Git.

Activation is generated for the Docker container machine. Docker Compose uses a fixed hostname and MAC address so secrets/activation.dat can be reused across runs in the same repository.

## One Command Setup

Linux:

```bash
./start.sh
```

macOS Terminal:

```bash
./start.command
```

macOS Finder:

```text
Double-click start.command
```

Windows PowerShell:

```powershell
.\start.ps1
```

Windows Explorer:

```text
Double-click start.cmd
```

If Windows blocks script execution, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\start.ps1
```

## What The Setup Script Does

The setup script:

- asks whether to reset the existing Docker installation
- preserves existing LivChart config and data volumes by default
- optionally resets Docker volumes for a clean starter installation
- asks which AI provider to use
- supports livaicloud as the default provider
- supports Ollama local AI model options when selected
- checks memory and free disk before starting an Ollama setup
- builds the LivChart Docker image
- downloads the LivChart Linux package from GitHub Releases
- starts Ollama and pulls the selected model when an Ollama option is selected
- activates the license for the Docker machine
- starts LivChart on http://localhost:7000

On macOS, start.command checks Docker Desktop and opens it automatically when possible before running the shared setup flow.

## AI Provider Options

Default provider:

- livaicloud

Optional local AI provider:

- Ollama with livchart/qwen3.5-9b-q6:latest
- Ollama with livchart/mistral-nemo-12b-q6:latest

Recommended resources:

- qwen3.5-9b-q6: at least 16 GB memory and 12 GB free disk
- mistral-nemo-12b-q6: at least 24 GB memory and 16 GB free disk

## Login

Application URL:

```text
http://localhost:7000
```

Default LivChart login:

```text
User: admin
Password: admin123
```

## Starter Config and Data

New installations use files from:

```text
starter-config/
starter-data/DataSet/
```

starter-config contains LivChart configuration JSON files. starter-data/DataSet contains the bundled LivChart DataStudio database.

When the container starts, it copies these seed files into the livchart-config and livchart-data volumes only when those volumes are empty. Existing volumes are preserved.

## Manual Commands

Build the image:

```bash
docker compose build livchart
```

Activate the license:

```bash
./scripts/activate-license.sh
```

Windows PowerShell:

```powershell
.\scripts\activate-license.ps1
```

Start with livaicloud:

```bash
LIVCHART_AI_PROVIDER=livaicloud docker compose up -d livchart
```

Start with Ollama:

```bash
LIVCHART_AI_PROVIDER=ollama \
LIVCHART_OLLAMA_MODEL=livchart/qwen3.5-9b-q6:latest \
docker compose --profile ollama up -d ollama livchart
```

Check status:

```bash
docker compose ps
```

Start over from a clean state:

```bash
docker compose down -v
```

## GitHub Notes

Do not commit the LivChart ZIP package, license key, authentication key, or activation file.

- The LivChart package is downloaded from GitHub Releases during Docker build.
- The license or authentication key stays local under secrets/.
- secrets/, packages/, data/, logs/, .docker-config/, and .env are ignored by Git.

## Related Links

- LivChart product website: https://livchart.com
- LivChart release packages: https://github.com/livchart/livchart/releases
- LivChart GitHub organization: https://github.com/livchart

## Search Keywords

LivChart Local AI Analytics, LivChart AI Analytics, local AI data analysis, Docker analytics platform, local AI BI, private AI analytics, on-premise business intelligence, Ollama analytics, LM Studio analytics, local LLM analytics, AI dashboard software, AI chart generator, self-service BI, ETL analytics, Analytics Studio.
