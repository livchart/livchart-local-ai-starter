[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is not installed or not available in PATH."
}

docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose v2 is not available."
}

$secretsDir = Join-Path $repoRoot "secrets"
New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null

$licenseFile = $env:LIVCHART_LICENSE_FILE
if ([string]::IsNullOrWhiteSpace($licenseFile)) {
    $defaultLicense = Join-Path $secretsDir "license.key"
    if (Test-Path -LiteralPath $defaultLicense) {
        $licenseFile = $defaultLicense
    } else {
        $licenseFile = Get-ChildItem -LiteralPath $secretsDir -Filter "*.key" -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if ([string]::IsNullOrWhiteSpace($licenseFile) -or -not (Test-Path -LiteralPath $licenseFile)) {
    Write-Error "Missing LivChart license file.`nPut it under secrets/license.key or any secrets/*.key file."
    exit 1
}

$activationFile = Join-Path $secretsDir "activation.dat"
if (-not (Test-Path -LiteralPath $activationFile)) {
    New-Item -ItemType File -Force -Path $activationFile | Out-Null
}

$env:LIVCHART_LICENSE_FILE = (Resolve-Path -LiteralPath $licenseFile).Path
$env:LIVCHART_ACTIVATION_FILE = (Resolve-Path -LiteralPath $activationFile).Path
if ([string]::IsNullOrWhiteSpace($env:LIVCHART_HOST_PORT)) {
    $env:LIVCHART_HOST_PORT = "7000"
}

function Get-TotalMemoryGb {
    try {
        $memoryBytes = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
        return [int][Math]::Ceiling($memoryBytes / 1GB)
    } catch {
        return 0
    }
}

function Get-FreeDiskGb {
    try {
        $root = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath ".").Path)
        $driveName = $root.Substring(0, 1)
        $drive = Get-PSDrive -Name $driveName
        return [int][Math]::Floor($drive.Free / 1GB)
    } catch {
        return 0
    }
}

function Confirm-OllamaRequirements {
    param(
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][int]$MinimumMemoryGb,
        [Parameter(Mandatory = $true)][int]$MinimumDiskGb
    )

    $detectedMemoryGb = Get-TotalMemoryGb
    $detectedDiskGb = Get-FreeDiskGb
    $hasWarning = $false

    Write-Host ""
    Write-Host "Checking local system requirements for $Model..."
    Write-Host "  Recommended memory: $MinimumMemoryGb GB"
    Write-Host "  Recommended free disk: $MinimumDiskGb GB"

    if ($detectedMemoryGb -gt 0) {
        Write-Host "  Detected memory: $detectedMemoryGb GB"
        if ($detectedMemoryGb -lt $MinimumMemoryGb) {
            Write-Host "  Warning: detected memory is below the recommended value."
            $hasWarning = $true
        }
    } else {
        Write-Host "  Warning: memory could not be detected."
        $hasWarning = $true
    }

    if ($detectedDiskGb -gt 0) {
        Write-Host "  Detected free disk: $detectedDiskGb GB"
        if ($detectedDiskGb -lt $MinimumDiskGb) {
            Write-Host "  Warning: free disk space is below the recommended value."
            $hasWarning = $true
        }
    } else {
        Write-Host "  Warning: free disk space could not be detected."
        $hasWarning = $true
    }

    Write-Host "  Note: Docker Desktop WSL 2 memory allocation can be lower than host memory."

    if ($hasWarning) {
        Write-Host ""
        $continueChoice = Read-Host "Continue with this Ollama model anyway? [y/N]"
        if ($continueChoice -in @("y", "Y", "yes", "YES", "Yes")) {
            Write-Host "Continuing with Ollama setup."
            return $true
        }
        Write-Host "Ollama setup cancelled."
        return $false
    }

    Write-Host "System check passed for this Ollama model."
    return $true
}

Write-Host ""
Write-Host "Do you want to reset the LivChart installation?"
Write-Host "  This removes Docker containers and LivChart Docker volumes."
Write-Host "  Your local license file and activation file under secrets/ are preserved."
Write-Host ""

$resetChoice = Read-Host "Reset installation? [y/N]"
if ([string]::IsNullOrWhiteSpace($resetChoice)) {
    $resetChoice = "N"
}

switch ($resetChoice) {
    { $_ -in @("y", "Y", "yes", "YES", "Yes") } {
        Write-Host "Resetting LivChart Docker installation..."
        & docker compose down -v --remove-orphans
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose down -v --remove-orphans failed."
        }
    }
    { $_ -in @("n", "N", "no", "NO", "No") } {
        Write-Host "Keeping existing Docker volumes."
    }
    default {
        Write-Error "Invalid selection: $resetChoice"
        exit 1
    }
}

Write-Host ""
Write-Host "Choose AI provider for LivChart:"
Write-Host "  1) livaicloud (default, recommended)"
Write-Host "  2) Ollama - livchart/qwen3.5-9b-q6:latest"
Write-Host "  3) Ollama - livchart/mistral-nemo-12b-q6:latest"
Write-Host ""

$aiChoice = Read-Host "Selection [1]"
if ([string]::IsNullOrWhiteSpace($aiChoice)) {
    $aiChoice = "1"
}

$composeArgs = @("compose")
switch ($aiChoice) {
    "1" {
        $env:LIVCHART_AI_PROVIDER = "livaicloud"
        Remove-Item Env:\LIVCHART_OLLAMA_MODEL -ErrorAction SilentlyContinue
        Write-Host "livaicloud selected. No local AI model resources are required."
    }
    "2" {
        $env:LIVCHART_AI_PROVIDER = "ollama"
        $env:LIVCHART_OLLAMA_MODEL = "livchart/qwen3.5-9b-q6:latest"
        $composeArgs += @("--profile", "ollama")
        if (-not (Confirm-OllamaRequirements -Model $env:LIVCHART_OLLAMA_MODEL -MinimumMemoryGb 16 -MinimumDiskGb 12)) {
            exit 1
        }
    }
    "3" {
        $env:LIVCHART_AI_PROVIDER = "ollama"
        $env:LIVCHART_OLLAMA_MODEL = "livchart/mistral-nemo-12b-q6:latest"
        $composeArgs += @("--profile", "ollama")
        if (-not (Confirm-OllamaRequirements -Model $env:LIVCHART_OLLAMA_MODEL -MinimumMemoryGb 24 -MinimumDiskGb 16)) {
            exit 1
        }
    }
    default {
        Write-Error "Invalid selection: $aiChoice"
        exit 1
    }
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    & docker @composeArgs @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed."
    }
}

Invoke-Compose build livchart

if ($env:LIVCHART_AI_PROVIDER -eq "ollama") {
    Invoke-Compose up -d ollama
    Write-Host "Waiting for Ollama to be ready..."
    $ollamaReady = $false
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        & docker @composeArgs exec -T ollama ollama list *> $null
        if ($LASTEXITCODE -eq 0) {
            $ollamaReady = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $ollamaReady) {
        throw "Ollama did not become ready."
    }

    Write-Host "Pulling Ollama model: $env:LIVCHART_OLLAMA_MODEL"
    Invoke-Compose exec -T ollama ollama pull $env:LIVCHART_OLLAMA_MODEL
}

& (Join-Path $repoRoot "scripts/activate-license.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "License activation failed."
}

Invoke-Compose up -d --remove-orphans livchart

Write-Host "Waiting for LivChart to respond on http://localhost:$env:LIVCHART_HOST_PORT..."
$livchartReady = $false
for ($attempt = 1; $attempt -le 60; $attempt++) {
    try {
        Invoke-WebRequest -Method Head -Uri "http://localhost:$env:LIVCHART_HOST_PORT/" -TimeoutSec 5 -UseBasicParsing | Out-Null
        $livchartReady = $true
        break
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $livchartReady) {
    Write-Error "LivChart did not respond on http://localhost:$env:LIVCHART_HOST_PORT within 120 seconds.`nRun: docker compose logs --tail=200 livchart"
    exit 1
}

Write-Host ""
Write-Host "LivChart is starting:"
Write-Host "  http://localhost:$env:LIVCHART_HOST_PORT"
Write-Host ""
Write-Host "Default login:"
Write-Host "  user: admin"
Write-Host "  password: admin123"
Write-Host ""
Write-Host "Sample data:"
Write-Host "  LivChart DataSet is preloaded from starter-data/DataSet."
Write-Host ""

$providerMessage = "AI provider: $env:LIVCHART_AI_PROVIDER"
if ($env:LIVCHART_AI_PROVIDER -eq "ollama") {
    $providerMessage = "$providerMessage ($env:LIVCHART_OLLAMA_MODEL)"
}
Write-Host $providerMessage
