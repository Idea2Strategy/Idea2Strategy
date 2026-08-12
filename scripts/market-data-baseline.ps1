Set-StrictMode -Version Latest

function Resolve-BaselineRoot {
    param([Parameter(Mandatory = $true)][string]$BaselinePath)

    if (-not (Test-Path -LiteralPath $BaselinePath -PathType Container)) {
        throw "Baseline directory is missing: $BaselinePath"
    }
    return (Resolve-Path -LiteralPath $BaselinePath).Path
}

function Resolve-BaselineFile {
    param(
        [Parameter(Mandatory = $true)][string]$BaselineRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Baseline file path must be relative: $RelativePath"
    }
    $normalised = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $BaselineRoot $normalised))
    $rootPrefix = $BaselineRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Baseline file path escapes the baseline directory: $RelativePath"
    }
    return $candidate
}

function Get-LowerSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-BaselineManifest {
    param([Parameter(Mandatory = $true)][string]$BaselineRoot)

    $manifestPath = Join-Path $BaselineRoot "baseline-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Baseline manifest is missing: $manifestPath"
    }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Baseline manifest is not valid JSON: $($_.Exception.Message)"
    }
    if ([int]$manifest.schema_version -ne 1) {
        throw "Unsupported baseline manifest schema_version: $($manifest.schema_version)"
    }
    return $manifest
}

function Assert-Sha256Text {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Value -cnotmatch '^[0-9a-f]{64}$') {
        throw "$Label must be a lowercase SHA-256 value."
    }
}

function Assert-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $Name"
    }
}

function Invoke-CheckedNative {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$Capture
    )

    if ($Capture) {
        $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("i2s-native-stderr-" + [guid]::NewGuid().ToString('N') + '.log')
        try {
            $output = & $FilePath @Arguments 2> $stderrPath
            $exitCode = $LASTEXITCODE
            $stderrText = if (Test-Path -LiteralPath $stderrPath) {
                (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue)
            } else { '' }
        }
        finally {
            Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
        $output = @()
        $stderrText = ''
    }
    if ($exitCode -ne 0) {
        $safeMessage = ((($output | Out-String) + $stderrText).Trim())
        throw "$FilePath failed with exit code $exitCode. $safeMessage"
    }
    if ($Capture) {
        return $output
    }
}

function ConvertTo-DockerReachableUrl {
    param([Parameter(Mandatory = $true)][string]$Url)
    return $Url.Replace('://localhost', '://host.docker.internal').Replace('://127.0.0.1', '://host.docker.internal')
}

function ConvertTo-DockerToolArgument {
    param(
        [Parameter(Mandatory = $true)][string]$Argument,
        [Parameter(Mandatory = $true)][string]$BaselineRoot
    )
    $isBaselinePath = $Argument.StartsWith($BaselineRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $Argument.StartsWith("--file=$BaselineRoot", [System.StringComparison]::OrdinalIgnoreCase)
    $converted = $Argument.Replace($BaselineRoot, '/baseline')
    if ($isBaselinePath) {
        $converted = $converted.Replace('\', '/')
    }
    if ($converted -match '^--dbname=') {
        $converted = ConvertTo-DockerReachableUrl -Url $converted
    }
    return $converted
}

function Invoke-BaselinePostgresTool {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('psql', 'pg_dump', 'pg_restore')][string]$Tool,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$BaselineRoot,
        [switch]$UseDockerTools,
        [string]$DockerNetwork = '',
        [switch]$Capture
    )

    if (-not $UseDockerTools) {
        Assert-CommandAvailable -Name $Tool
        return Invoke-CheckedNative -FilePath $Tool -Arguments $Arguments -Capture:$Capture
    }
    Assert-CommandAvailable -Name 'docker'
    $dockerArguments = @('run', '--rm', '-v', "${BaselineRoot}:/baseline")
    if (-not [string]::IsNullOrWhiteSpace($DockerNetwork)) {
        $dockerArguments += @('--network', $DockerNetwork)
    }
    $dockerArguments += @('postgres:16-alpine', $Tool)
    $dockerArguments += @($Arguments | ForEach-Object {
        ConvertTo-DockerToolArgument -Argument ([string]$_) -BaselineRoot $BaselineRoot
    })
    return Invoke-CheckedNative -FilePath 'docker' -Arguments $dockerArguments -Capture:$Capture
}

function Invoke-BaselineAwsTool {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$BaselineRoot,
        [switch]$UseDockerTools,
        [string]$DockerNetwork = '',
        [switch]$Capture
    )

    if (-not $UseDockerTools) {
        Assert-CommandAvailable -Name 'aws'
        return Invoke-CheckedNative -FilePath 'aws' -Arguments $Arguments -Capture:$Capture
    }
    Assert-CommandAvailable -Name 'docker'
    $dockerArguments = @('run', '--rm', '-v', "${BaselineRoot}:/baseline")
    $awsDirectory = Join-Path $HOME '.aws'
    if (Test-Path -LiteralPath $awsDirectory -PathType Container) {
        $dockerArguments += @('-v', "${awsDirectory}:/root/.aws:ro")
    }
    foreach ($variableName in @(
        'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN',
        'AWS_PROFILE', 'AWS_REGION', 'AWS_DEFAULT_REGION'
    )) {
        if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variableName))) {
            $dockerArguments += @('-e', $variableName)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($DockerNetwork)) {
        $dockerArguments += @('--network', $DockerNetwork)
    }
    $dockerArguments += 'amazon/aws-cli:2.36.2'
    $dockerArguments += @($Arguments | ForEach-Object {
        $converted = ConvertTo-DockerToolArgument -Argument ([string]$_) -BaselineRoot $BaselineRoot
        if ($converted -match '^https?://') { $converted = ConvertTo-DockerReachableUrl -Url $converted }
        $converted
    })
    return Invoke-CheckedNative -FilePath 'docker' -Arguments $dockerArguments -Capture:$Capture
}
