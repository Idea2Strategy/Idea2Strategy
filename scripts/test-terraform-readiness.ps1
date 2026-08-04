[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$terraformRoots = @(
    "infra/terraform/bootstrap",
    "infra/terraform/environments/development"
)

$terraform = Get-Command terraform -ErrorAction SilentlyContinue
if ($null -eq $terraform) {
    throw "Terraform 1.15.x is required. CI installs it explicitly; local contributors may use the documented Docker command."
}

$version = (& terraform version -json | ConvertFrom-Json).terraform_version
if ($version -notmatch '^1\.15\.') {
    throw "Terraform 1.15.x is required; found $version."
}

Push-Location $root
try {
    & terraform fmt -check -recursive infra/terraform
    if ($LASTEXITCODE -ne 0) {
        throw "terraform fmt -check failed."
    }

    foreach ($relativePath in $terraformRoots) {
        $absolutePath = Join-Path $root $relativePath
        $safeName = $relativePath.Replace('/', '-').Replace('\', '-')
        $dataDir = Join-Path $root ".harness/local/tmp/terraform/$safeName"
        New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

        $previousDataDir = $env:TF_DATA_DIR
        try {
            $env:TF_DATA_DIR = $dataDir
            & terraform "-chdir=$absolutePath" init -backend=false -input=false -lockfile=readonly
            if ($LASTEXITCODE -ne 0) {
                throw "terraform init failed for $relativePath."
            }

            & terraform "-chdir=$absolutePath" validate
            if ($LASTEXITCODE -ne 0) {
                throw "terraform validate failed for $relativePath."
            }
        } finally {
            $env:TF_DATA_DIR = $previousDataDir
        }
    }

    & (Join-Path $PSScriptRoot "test-full-terraform-architecture.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Low-cost full Terraform architecture checks failed."
    }
} finally {
    Pop-Location
}

Write-Output "Terraform formatting, readonly lockfile initialization, and validation passed."
