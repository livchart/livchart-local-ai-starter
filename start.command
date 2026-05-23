#!/bin/sh
set -eu

cd "$(dirname "$0")" || exit 1

echo "LivChart Local AI Starter for macOS"
echo

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This launcher is intended for macOS. Use ./start.sh on Linux." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker Desktop is not installed or Docker is not available in PATH." >&2
  echo "Install Docker Desktop for macOS, start it, then run this launcher again." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is not available." >&2
  echo "Install or update Docker Desktop for macOS, then run this launcher again." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  if [ -d "/Applications/Docker.app" ]; then
    echo "Starting Docker Desktop..."
    open -a Docker >/dev/null 2>&1 || true
  else
    echo "Docker Desktop is not running." >&2
  fi

  echo "Waiting for Docker Desktop to be ready..."
  ready=0
  for _ in $(seq 1 90); do
    if docker info >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 2
  done

  if [ "$ready" != "1" ]; then
    echo "Docker Desktop did not become ready within 180 seconds." >&2
    echo "Start Docker Desktop manually, then run this launcher again." >&2
    exit 1
  fi
fi

exec ./start.sh
