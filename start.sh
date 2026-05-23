#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed or not available in PATH." >&2
  exit 1
fi

mkdir -p secrets

license_file="${LIVCHART_LICENSE_FILE:-}"
if [ -z "$license_file" ]; then
  if [ -f "secrets/license.key" ]; then
    license_file="./secrets/license.key"
  else
    license_file="$(find ./secrets -maxdepth 1 -type f -name '*.key' | sort | head -n 1 || true)"
  fi
fi

if [ -z "$license_file" ] || [ ! -f "$license_file" ]; then
  echo "Missing LivChart license file." >&2
  echo "Put it under secrets/license.key or any secrets/*.key file." >&2
  exit 1
fi

touch secrets/activation.dat

export LIVCHART_LICENSE_FILE="$license_file"
export LIVCHART_ACTIVATION_FILE="${LIVCHART_ACTIVATION_FILE:-./secrets/activation.dat}"
export LIVCHART_HOST_PORT="${LIVCHART_HOST_PORT:-7000}"

total_memory_gb() {
  if [ -r /proc/meminfo ]; then
    awk '/MemTotal/ { printf "%d", ($2 / 1024 / 1024) + 0.999 }' /proc/meminfo
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%d", ($1 / 1024 / 1024 / 1024) + 0.999 }'
  else
    printf "0"
  fi
}

free_disk_gb() {
  df -Pk . | awk 'NR == 2 { printf "%d", $4 / 1024 / 1024 }'
}

check_ollama_requirements() {
  model="$1"
  minimum_memory_gb="$2"
  minimum_disk_gb="$3"
  detected_memory_gb="$(total_memory_gb)"
  detected_disk_gb="$(free_disk_gb)"
  has_warning=0

  echo
  echo "Checking local system requirements for ${model}..."
  echo "  Recommended memory: ${minimum_memory_gb} GB"
  echo "  Recommended free disk: ${minimum_disk_gb} GB"

  if [ "$detected_memory_gb" -gt 0 ]; then
    echo "  Detected memory: ${detected_memory_gb} GB"
    if [ "$detected_memory_gb" -lt "$minimum_memory_gb" ]; then
      echo "  Warning: detected memory is below the recommended value."
      has_warning=1
    fi
  else
    echo "  Warning: memory could not be detected."
    has_warning=1
  fi

  echo "  Detected free disk: ${detected_disk_gb} GB"
  if [ "$detected_disk_gb" -lt "$minimum_disk_gb" ]; then
    echo "  Warning: free disk space is below the recommended value."
    has_warning=1
  fi

  if [ "$(uname -s)" = "Darwin" ]; then
    echo "  Note: Docker Desktop memory allocation can be lower than host memory."
  fi

  if [ "$has_warning" = "1" ]; then
    echo
    read -r -p "Continue with this Ollama model anyway? [y/N]: " continue_choice
    continue_choice="${continue_choice:-N}"
    case "$continue_choice" in
      y|Y|yes|YES|Yes)
        echo "Continuing with Ollama setup."
        ;;
      *)
        echo "Ollama setup cancelled."
        exit 1
        ;;
    esac
  else
    echo "System check passed for this Ollama model."
  fi
}

cat <<'TXT'

Do you want to reset the LivChart installation?
  This removes Docker containers and LivChart Docker volumes.
  Your local license file and activation file under secrets/ are preserved.

TXT

read -r -p "Reset installation? [y/N]: " reset_choice
reset_choice="${reset_choice:-N}"
case "$reset_choice" in
  y|Y|yes|YES|Yes)
    echo "Resetting LivChart Docker installation..."
    docker compose down -v --remove-orphans
    ;;
  n|N|no|NO|No)
    echo "Keeping existing Docker volumes."
    ;;
  *)
    echo "Invalid selection: $reset_choice" >&2
    exit 1
    ;;
esac

cat <<'TXT'

Choose AI provider for LivChart:
  1) livaicloud (default, recommended)
  2) Ollama - livchart/qwen3.5-9b-q6:latest
  3) Ollama - livchart/mistral-nemo-12b-q6:latest

TXT

read -r -p "Selection [1]: " ai_choice
ai_choice="${ai_choice:-1}"

case "$ai_choice" in
  1)
    export LIVCHART_AI_PROVIDER="livaicloud"
    unset LIVCHART_OLLAMA_MODEL
    compose=(docker compose)
    echo "livaicloud selected. No local AI model resources are required."
    ;;
  2)
    export LIVCHART_AI_PROVIDER="ollama"
    export LIVCHART_OLLAMA_MODEL="livchart/qwen3.5-9b-q6:latest"
    compose=(docker compose --profile ollama)
    check_ollama_requirements "${LIVCHART_OLLAMA_MODEL}" 16 12
    ;;
  3)
    export LIVCHART_AI_PROVIDER="ollama"
    export LIVCHART_OLLAMA_MODEL="livchart/mistral-nemo-12b-q6:latest"
    compose=(docker compose --profile ollama)
    check_ollama_requirements "${LIVCHART_OLLAMA_MODEL}" 24 16
    ;;
  *)
    echo "Invalid selection: $ai_choice" >&2
    exit 1
    ;;
esac

"${compose[@]}" build livchart

if [ "${LIVCHART_AI_PROVIDER}" = "ollama" ]; then
  "${compose[@]}" up -d ollama
  echo "Waiting for Ollama to be ready..."
  for _ in $(seq 1 60); do
    if "${compose[@]}" exec -T ollama ollama list >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  echo "Pulling Ollama model: ${LIVCHART_OLLAMA_MODEL}"
  "${compose[@]}" exec -T ollama ollama pull "${LIVCHART_OLLAMA_MODEL}"
fi

./scripts/activate-license.sh
"${compose[@]}" up -d --remove-orphans livchart

echo "Waiting for LivChart to respond on http://localhost:${LIVCHART_HOST_PORT}..."
livchart_ready=0
if command -v curl >/dev/null 2>&1; then
  for _ in $(seq 1 60); do
    if curl -fsI "http://localhost:${LIVCHART_HOST_PORT}/" >/dev/null 2>&1; then
      livchart_ready=1
      break
    fi
    sleep 2
  done
else
  livchart_ready=1
fi

if [ "$livchart_ready" != "1" ]; then
  echo "LivChart did not respond on http://localhost:${LIVCHART_HOST_PORT} within 120 seconds." >&2
  echo "Run: docker compose logs --tail=200 livchart" >&2
  exit 1
fi

cat <<'TXT'

LivChart is starting:
  http://localhost:7000

Default login:
  user: admin
  password: admin123

Sample data:
  LivChart DataSet is preloaded from starter-data/DataSet.

TXT

echo "AI provider: ${LIVCHART_AI_PROVIDER}${LIVCHART_OLLAMA_MODEL:+ (${LIVCHART_OLLAMA_MODEL})}"
