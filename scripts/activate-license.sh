#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

license_file="${LIVCHART_LICENSE_FILE:-}"
if [ -z "$license_file" ]; then
  if [ -f "secrets/license.key" ]; then
    license_file="./secrets/license.key"
  else
    license_file="$(find ./secrets -maxdepth 1 -type f -name '*.key' | sort | head -n 1 || true)"
  fi
fi

if [ -z "$license_file" ] || [ ! -f "$license_file" ]; then
  echo "Missing LivChart license file under secrets/." >&2
  exit 1
fi

mkdir -p secrets
touch secrets/activation.dat

if python3 - <<'PY'
import json
from pathlib import Path

activation_file = Path("secrets/activation.dat")
try:
    activation = json.loads(activation_file.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

if activation.get("machine_id") and activation.get("signature"):
    raise SystemExit(0)
raise SystemExit(1)
PY
then
  echo "Existing activation file found; skipping license activation."
  exit 0
fi

license_abs="$(realpath "$license_file")"
activation_abs="$(realpath secrets/activation.dat)"

docker run --rm -i \
  --hostname livchart-local \
  --mac-address 02:42:ac:11:00:10 \
  --entrypoint python3 \
  -v "${license_abs}:/opt/livchart/license.key:ro" \
  -v "${activation_abs}:/opt/livchart/activation.dat" \
  livchart-local-ai-starter:latest - <<'PY'
import base64
import hashlib
import json
import platform
import urllib.error
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

license_file = Path("/opt/livchart/license.key")
activation_file = Path("/opt/livchart/activation.dat")

content = json.loads(license_file.read_text(encoding="utf-8"))
payload = json.loads(base64.b64decode(content["payload"]).decode("utf-8"))
license_key = payload["license_key"]
email = payload["email"]

machine_id = hashlib.sha256(
    f"{uuid.getnode()}-{platform.node()}-{platform.machine()}-{platform.processor()}".encode()
).hexdigest()

request = urllib.request.Request(
    "https://livchart.com/api/activate.php",
    data=json.dumps({
        "license_key": license_key,
        "machine_id": machine_id,
        "email": email,
    }).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        result = json.loads(response.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    raise SystemExit(f"Activation server returned HTTP {exc.code}") from exc
except urllib.error.URLError as exc:
    raise SystemExit(f"Activation server connection failed: {exc.reason}") from exc

if not result.get("success"):
    raise SystemExit(result.get("message") or "Activation failed")

activation_file.write_text(json.dumps({
    "machine_id": machine_id,
    "signature": result["activation_signature"],
    "activated_at": datetime.now().isoformat(),
}, indent=2), encoding="utf-8")

print("License activated for Docker machine id.")
PY
