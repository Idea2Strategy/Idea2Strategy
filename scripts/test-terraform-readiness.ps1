[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$terraformRoots = @(
    "infra/terraform/bootstrap",
    "infra/terraform/ci-identity",
    "infra/terraform/artifact-foundation",
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

    & (Join-Path $PSScriptRoot "test-runtime-deployment-wiring.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment runtime wiring checks failed."
    }

    # Derives what backend-batch must be given from the batch source itself, so a newly added
    # mandatory @Value is caught instead of waiting for the container to exit 1 unobserved. Prints
    # that it skipped when the backend submodule is absent, which is the case in root CI.
    & (Join-Path $PSScriptRoot "test-batch-runtime-properties.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "backend-batch mandatory runtime properties are not supplied by the development host."
    }

    # Derives the runtime roles from the host template and fails when the release does not roll out to
    # one of them. Read-only, so it belongs in ordinary CI rather than behind AWS credentials.
    & (Join-Path $PSScriptRoot "test-runtime-rollout-coverage.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "The Development release does not roll out its published images to every runtime role."
    }
} finally {
    Pop-Location
}

Write-Output "Terraform formatting, readonly lockfile initialization, and validation passed."
