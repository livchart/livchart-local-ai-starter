[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
Set-Location $repoRoot

$licenseFile = $env:LIVCHART_LICENSE_FILE
if ([string]::IsNullOrWhiteSpace($licenseFile)) {
    $defaultLicense = Join-Path $repoRoot "secrets/license.key"
    if (Test-Path -LiteralPath $defaultLicense) {
        $licenseFile = $defaultLicense
    } else {
        $licenseFile = Get-ChildItem -LiteralPath (Join-Path $repoRoot "secrets") -Filter "*.key" -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if ([string]::IsNullOrWhiteSpace($licenseFile) -or -not (Test-Path -LiteralPath $licenseFile)) {
    throw "Missing LivChart license file under secrets."
}

$secretsDir = Join-Path $repoRoot "secrets"
New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null

$activationFile = $env:LIVCHART_ACTIVATION_FILE
if ([string]::IsNullOrWhiteSpace($activationFile)) {
    $activationFile = Join-Path $secretsDir "activation.dat"
}
if (-not (Test-Path -LiteralPath $activationFile)) {
    New-Item -ItemType File -Force -Path $activationFile | Out-Null
}

try {
    $activation = Get-Content -LiteralPath $activationFile -Raw | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($activation.machine_id) -and -not [string]::IsNullOrWhiteSpace($activation.signature)) {
        Write-Host "Existing activation file found; skipping license activation."
        exit 0
    }
} catch {
    # Empty or invalid activation files are activated below.
}

$licensePath = (Resolve-Path -LiteralPath $licenseFile).Path
$activationPath = (Resolve-Path -LiteralPath $activationFile).Path
$image = if ([string]::IsNullOrWhiteSpace($env:LIVCHART_IMAGE)) { "livchart-local-ai-starter:latest" } else { $env:LIVCHART_IMAGE }

$activationPython = @'
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
'@

$licenseVolume = "${licensePath}:/opt/livchart/license.key:ro"
$activationVolume = "${activationPath}:/opt/livchart/activation.dat"

$activationPython | docker run --rm -i `
    --hostname livchart-local `
    --mac-address 02:42:ac:11:00:10 `
    --entrypoint python3 `
    -v $licenseVolume `
    -v $activationVolume `
    $image -

if ($LASTEXITCODE -ne 0) {
    throw "License activation failed."
}
