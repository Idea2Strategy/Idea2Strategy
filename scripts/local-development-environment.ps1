function New-LocalDevelopmentSecret {
    $bytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }

    return [Convert]::ToBase64String($bytes)
}

function Expand-LocalDevelopmentSecretPlaceholders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    foreach ($name in $Names) {
        if ($name -notmatch '^[A-Z][A-Z0-9_]+$') {
            throw "Local environment secret name is invalid: $name"
        }
        $placeholder = "__GENERATE_$($name)__"
        if (-not $Content.Contains($placeholder)) {
            throw "Local environment secret placeholder is missing: $placeholder"
        }
        $Content = $Content.Replace($placeholder, (New-LocalDevelopmentSecret))
    }

    return $Content
}
