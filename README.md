# LivChart Local AI Starter

Run LivChart with Docker on Linux, macOS, or Windows. During the image build, the LivChart Linux package is downloaded from GitHub Releases, then the starter configuration and the bundled LivChart DataSet database are added to the image.

This starter does not run PostgreSQL. The AI provider is selected during setup: `livaicloud` is the default, with two optional Ollama models available.

## About LivChart

LivChart is developed by Liv Yazilim ve Danismanlik Ltd. Sti. The LivChart GitHub organization publishes release packages and deployment starters for LivChart AI Analytics and LivChart Local AI Analytics.

LivChart AI Analytics is an AI-powered business intelligence and data analysis platform for building governed dashboards, charts, reports, and Analytics Studio workbooks from business data. LivChart Local AI Analytics brings the same analytics workflow to local and private AI environments, including on-premise BI, local model providers, private data analytics, and secure AI-assisted reporting.

Product website: https://livchart.com

Company website: https://livyazilim.com

## Requirements

- Linux: Docker Engine or Docker Desktop
- macOS: Docker Desktop
- Windows: Docker Desktop with WSL 2 backend
- Docker Compose v2
- A valid LivChart license/authentication key file

## License

Do not commit your license/authentication key to Git. For local runs, place it here:

```text
secrets/license.key
```

The filename can be different; the setup script automatically uses the first `secrets/*.key` file if `secrets/license.key` is not present. The `secrets/` folder is ignored by Git.

Activation is generated for the Docker container machine. Compose uses a fixed hostname and MAC address so `secrets/activation.dat` can be reused across runs in the same repo.

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

The setup script:

- Asks whether to reset the existing Docker installation:
  - `No` keeps existing LivChart config/data volumes (default).
  - `Yes` runs `docker compose down -v --remove-orphans` and starts from the bundled starter config/data again.
- Asks which AI provider to use:
  - `livaicloud` (default, recommended)
  - `ollama` with `livchart/qwen3.5-9b-q6:latest`
  - `ollama` with `livchart/mistral-nemo-12b-q6:latest`
- Checks local memory and free disk before starting an Ollama setup:
  - `qwen3.5-9b-q6`: recommends at least 16 GB memory and 12 GB free disk.
  - `mistral-nemo-12b-q6`: recommends at least 24 GB memory and 16 GB free disk.
- Builds the LivChart image.
- Downloads the Linux package from GitHub Releases.
- Starts Ollama and pulls the selected model when an Ollama option is selected.
- Activates the license for the Docker machine.
- Starts LivChart on `http://localhost:7000`.

On macOS, `start.command` checks Docker Desktop and opens it automatically when possible before running the shared setup flow.

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

`starter-config/` contains LivChart configuration JSON files. `starter-data/DataSet/` contains the bundled LivChart Data Studio database (`datastudio.duckdb`).

When the container starts, it copies these seed files into the `livchart-config` and `livchart-data` volumes only when those volumes are empty. Existing volumes are preserved.

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

Do not commit the LivChart ZIP package, license/authentication key, or activation file.

- The package is downloaded from GitHub Releases during the Docker build.
- The license/authentication key stays local under `secrets/`.
- `secrets/`, `packages/`, `data/`, `logs/`, `.docker-config/`, and `.env` are ignored by Git.
