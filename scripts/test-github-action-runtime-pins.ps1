$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$workflowRoot = Join-Path $repositoryRoot ".github/workflows"

$expectedPins = @{
    "actions/checkout"                      = @{ Sha = "3d3c42e5aac5ba805825da76410c181273ba90b1"; Tag = "v7.0.1" }
    "actions/download-artifact"             = @{ Sha = "3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c"; Tag = "v8.0.1" }
    "actions/setup-node"                    = @{ Sha = "820762786026740c76f36085b0efc47a31fe5020"; Tag = "v7.0.0" }
    "actions/setup-python"                  = @{ Sha = "5fda3b95a4ea91299a34e894583c3862153e4b97"; Tag = "v7.0.0" }
    "actions/upload-artifact"               = @{ Sha = "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"; Tag = "v7.0.1" }
    "aws-actions/configure-aws-credentials" = @{ Sha = "e6de054238d6b7531b4efff3b6587d9aade6a06c"; Tag = "v6.2.3" }
    "docker/setup-buildx-action"            = @{ Sha = "bb05f3f5519dd87d3ba754cc423b652a5edd6d2c"; Tag = "v4.2.0" }
    "docker/setup-qemu-action"              = @{ Sha = "96fe6ef7f33517b61c61be40b68a1882f3264fb8"; Tag = "v4.2.0" }
    "hashicorp/setup-terraform"             = @{ Sha = "dfe3c3f87815947d99a8997f908cb6525fc44e9e"; Tag = "v4.0.1" }
    "pnpm/action-setup"                     = @{ Sha = "0977fd99725f1db4007ccb2928dbb4e90d06cc86"; Tag = "v6.0.10" }
    "terraform-linters/setup-tflint"        = @{ Sha = "6e1e0642c0289bd619021bf6b34e3c08ed1e005a"; Tag = "v6.3.0" }
}

$usesPattern = '^\s*-\s+uses:\s+([^\s@]+)@([^\s#]+)(?:\s+#\s+(\S+))?\s*$'
$observed = 0
foreach ($workflowFile in Get-ChildItem -LiteralPath $workflowRoot -File -Filter "*.yml") {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $workflowFile.FullName) {
        $lineNumber++
        if ($line -notmatch '^\s*-\s+uses:') { continue }
        if ($line -notmatch $usesPattern) {
            throw "$($workflowFile.Name):$lineNumber has an unparsable action reference: $line"
        }

        $action = $Matches[1]
        $revision = $Matches[2]
        $tagComment = $Matches[3]
        if (-not $expectedPins.ContainsKey($action)) {
            throw "$($workflowFile.Name):$lineNumber uses an action without an approved immutable pin: $action"
        }

        $expected = $expectedPins[$action]
        if ($revision -ne $expected.Sha) {
            throw "$($workflowFile.Name):$lineNumber must pin $action@$($expected.Sha), found $revision"
        }
        if ($tagComment -ne $expected.Tag) {
            throw "$($workflowFile.Name):$lineNumber must annotate $action with # $($expected.Tag), found # $tagComment"
        }
        $observed++
    }
}

if ($observed -eq 0) {
    throw "No GitHub Action references were found."
}

Write-Host "GitHub Action immutable Node.js 24 runtime pins passed ($observed references)."
