[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$image = "hashicorp/terraform:1.15.8"

if ($null -eq (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is required when Terraform is not installed locally."
}

& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is not running."
}

$mount = "${root}:/workspace"
& docker run --rm -v $mount -w /workspace $image fmt -check -recursive infra/terraform
if ($LASTEXITCODE -ne 0) {
    throw "terraform fmt -check failed in Docker."
}

foreach ($relativePath in @("bootstrap", "ci-identity", "artifact-foundation", "environments/development")) {
    $workingDirectory = "/workspace/infra/terraform/$relativePath"
    $safeName = $relativePath.Replace('/', '-').Replace('\', '-')
    $hostDataDirectory = Join-Path $root ".local/tmp/terraform-docker/$safeName"
    New-Item -ItemType Directory -Force -Path $hostDataDirectory | Out-Null
    $containerDataDirectory = "/workspace/.local/tmp/terraform-docker/$safeName"
    & docker run --rm -e "TF_DATA_DIR=$containerDataDirectory" -e TF_VAR_aws_profile= -v $mount -w $workingDirectory $image init -backend=false -input=false -lockfile=readonly
    if ($LASTEXITCODE -ne 0) {
        throw "terraform init failed in Docker for $relativePath."
    }
    & docker run --rm -e "TF_DATA_DIR=$containerDataDirectory" -e TF_VAR_aws_profile= -v $mount -w $workingDirectory $image validate
    if ($LASTEXITCODE -ne 0) {
        throw "terraform validate failed in Docker for $relativePath."
    }
}

Write-Output "Docker-based Terraform readiness checks passed."
