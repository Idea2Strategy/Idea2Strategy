[CmdletBinding()]
param(
    [string]$BackendBaseUrl = 'http://localhost:18080',
    [string]$Email = 'developer@idea2strategy.local',
    [string]$Password = 'TestUser!2026'
)

$ErrorActionPreference = 'Stop'

function Invoke-IdentityRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Body
    )

    try {
        $response = Invoke-WebRequest -UseBasicParsing `
            -Uri ($BackendBaseUrl.TrimEnd('/') + $Path) `
            -Method Post `
            -ContentType 'application/json' `
            -Body ($Body | ConvertTo-Json -Compress) `
            -TimeoutSec 15
        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Content = [string]$response.Content
        }
    }
    catch {
        if ($_.Exception.Response) {
            return [pscustomobject]@{
                StatusCode = [int]$_.Exception.Response.StatusCode
                Content = [string]$_.ErrorDetails.Message
            }
        }
        throw
    }
}

$credentials = @{ email = $Email; password = $Password }
$login = Invoke-IdentityRequest -Path '/api/v1/auth/login' -Body $credentials
if ($login.StatusCode -ne 200) {
    if ($login.StatusCode -ne 401) {
        throw "Unable to check the local test account (HTTP $($login.StatusCode))."
    }

    $signup = Invoke-IdentityRequest -Path '/api/v1/auth/signup' -Body $credentials
    if ($signup.StatusCode -ne 202) {
        throw "Unable to create the local test account (HTTP $($signup.StatusCode))."
    }
    $signupBody = $signup.Content | ConvertFrom-Json
    if ($signupBody.verificationRequired -ne $false) {
        throw 'Local signup still requires email verification.'
    }

    $login = Invoke-IdentityRequest -Path '/api/v1/auth/login' -Body $credentials
    if ($login.StatusCode -ne 200) {
        throw "The local test account was created but login failed (HTTP $($login.StatusCode))."
    }
}

Write-Host 'Local customer account is ready.' -ForegroundColor Green
Write-Host "  Test ID:       $Email"
Write-Host "  Test password: $Password"
