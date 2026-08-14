$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '.github/workflows/development-frontend-release.yml'
$workflow = Get-Content -LiteralPath $path -Raw
foreach ($required in @('id-token: write', 'aws-actions/configure-aws-credentials@', 'role-to-assume:',
        'terraform plan -out=frontend.tfplan', 'terraform apply frontend.tfplan',
        'Test and build same-origin frontend without AWS credentials')) {
    if (-not $workflow.Contains($required)) { throw "Development frontend release workflow is missing: $required" }
}
foreach ($forbidden in @('VITE_OPERATOR_OIDC_', 'operator-pre-token', 'aws_cognito', 'lambda_package_')) {
    if ($workflow.Contains($forbidden)) { throw "Development frontend workflow retains human operator OIDC: $forbidden" }
}
Write-Output '{"status":"passed","workflow":"development-frontend-release","operatorAuth":"server-session","awsOidc":"preserved"}'
