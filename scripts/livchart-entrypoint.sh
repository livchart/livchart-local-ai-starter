#!/usr/bin/env bash
set -euo pipefail

cd "${LIVCHART_HOME:-/opt/livchart}"

mkdir -p config logs DataSet

python3 - <<'PY'
import json
import os
import shutil
import base64
from pathlib import Path

base = Path(os.environ.get("LIVCHART_HOME", "/opt/livchart"))
defaults = base / "defaults"
config = base / "config"
seed_data = base / "starter-data" / "DataSet"
data_dir = base / "DataSet"
config.mkdir(parents=True, exist_ok=True)
data_dir.mkdir(parents=True, exist_ok=True)

def copy_missing_tree(source, target):
    target.mkdir(parents=True, exist_ok=True)
    for child in source.iterdir():
        if child.name == ".gitkeep":
            continue
        child_target = target / child.name
        if child.is_dir():
            copy_missing_tree(child, child_target)
        elif not child_target.exists():
            shutil.copy2(child, child_target)

for source in sorted(defaults.iterdir()):
    target = config / source.name
    if source.is_dir():
        copy_missing_tree(source, target)
    elif source.suffix == ".json" and not target.exists():
        shutil.copy2(source, target)

if seed_data.exists() and not any(data_dir.iterdir()):
    shutil.copytree(seed_data, data_dir, dirs_exist_ok=True)

ai_path = config / "ai_settings.json"
ai_provider = os.environ.get("LIVCHART_AI_PROVIDER", "livaicloud").strip().lower()
ollama_model = os.environ.get("LIVCHART_OLLAMA_MODEL", "").strip() or "livchart/qwen3.5-9b-q6:latest"

try:
    ai_settings = json.loads(ai_path.read_text(encoding="utf-8")) if ai_path.exists() else {}
except Exception:
    ai_settings = {}

providers = ai_settings.setdefault("providers", {})
local_providers = ai_settings.setdefault("local_providers", {})
livaicloud = providers.setdefault("livaicloud", {
    "api_key": "",
    "model": "",
    "domain": "https://livchart.com",
})
livaicloud["enabled"] = True

if ai_provider == "ollama":
    livaicloud["active"] = False
    local_providers["ollama"] = {
        "host": "ollama",
        "port": "11434",
        "model": ollama_model,
        "enabled": True,
        "active": True,
        "ollama_temperature": 0.0,
        "ollama_top_p": 0.1,
        "ollama_seed": 42,
        "ollama_num_predict": 2400,
        "ollama_think": False,
    }
    ai_settings["default_provider"] = "ollama"
else:
    livaicloud["active"] = True
    if "ollama" in local_providers:
        local_providers["ollama"]["enabled"] = False
        local_providers["ollama"]["active"] = False
    ai_settings["default_provider"] = "livaicloud"

ai_settings.setdefault("ai_log_level", "basic")
ai_path.write_text(json.dumps(ai_settings, ensure_ascii=False, indent=2), encoding="utf-8")

license_email = ""
license_file = base / "license.key"
if license_file.exists():
    try:
        license_content = json.loads(license_file.read_text(encoding="utf-8"))
        payload = json.loads(base64.b64decode(license_content.get("payload", "")).decode("utf-8"))
        license_email = payload.get("email", "")
    except Exception:
        license_email = ""

company_path = config / "company_profile.json"
try:
    company_profile = json.loads(company_path.read_text(encoding="utf-8")) if company_path.exists() else {}
except Exception:
    company_profile = {}
if license_email and not company_profile.get("email"):
    company_profile["email"] = license_email
    if not company_profile.get("name"):
        company_profile["name"] = "LivChart Local Demo"
    company_path.write_text(json.dumps(company_profile, ensure_ascii=False, indent=2), encoding="utf-8")
PY

exec "$@"
