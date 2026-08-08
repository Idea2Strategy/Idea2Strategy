<#
.SYNOPSIS
    MFA 로 12시간 임시 AWS 세션을 받아 작업용 프로필에 넣는다.

.DESCRIPTION
    이 계정의 개발자 접근은 MFA 로 보호된 IAM 사용자다
    (infra/terraform/environments/development/developer-access.tf — 거의 모든 권한에
    aws:MultiFactorAuthPresent = true 조건이 붙어 있다). IAM Identity Center 는 쓰지 않으므로
    `aws sso login` 같은 브라우저 흐름은 존재하지 않는다.

    그래서 장기 키만 넣어두면 아무것도 못 한다 — 정책이 MFA 를 요구하기 때문이다. 다만
    `sts get-caller-identity` 는 MFA 조건이 없어 성공하므로, 연결됐다고 착각하기 쉽다.
    이 스크립트는 그 함정을 없앤다: MFA 로 세션을 받아 프로필에 심고, MFA 가 실제로
    붙었는지까지 확인한다.

    비밀값을 화면에 찍지 않는다. get-session-token 의 출력을 그대로 보면
    SecretAccessKey 와 SessionToken 이 평문으로 노출되고, 그 화면을 복사해 어딘가에 붙이는
    순간 12시간짜리라도 유출이다. 값은 `aws configure set` 으로 프로필에 바로 들어간다.

    12시간은 get-session-token 의 기본값(43200초)이며 이 계정 개발자들이 쓰는 그 세션이다.

.PARAMETER MfaCode
    인증 앱의 6자리 코드. 생략하면 물어본다.

.PARAMETER LongTermProfile
    장기 액세스 키가 든 프로필. 이 프로필은 세션을 받는 열쇠로만 쓰인다.

.PARAMETER TargetProfile
    임시 자격증명을 심을 프로필. runbook 과 스크립트들이 이 이름을 기대한다.

.PARAMETER DurationSeconds
    세션 길이. 기본 43200(12시간), IAM 사용자 최대 129600(36시간).

.EXAMPLE
    .\scripts\aws-session.ps1
    .\scripts\aws-session.ps1 -MfaCode 123456
#>
[CmdletBinding()]
param(
    [string]$MfaCode,
    [string]$LongTermProfile = 'i2s-longterm',
    [string]$TargetProfile = 'idea2strategy-terraform',
    [int]$DurationSeconds = 43200,
    [string]$Region = 'ap-northeast-2',
    [string]$ExpectedAccountId = '418553863687'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# AWS CLI 는 winget 설치 경로가 PATH 에 즉시 반영되지 않는 경우가 있다.
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    $candidate = 'C:\Program Files\Amazon\AWSCLIV2'
    if (Test-Path -LiteralPath (Join-Path $candidate 'aws.exe')) {
        $env:PATH = "$candidate;$env:PATH"
    } else {
        throw 'aws CLI 를 찾을 수 없다. winget install --id Amazon.AWSCLI 로 설치한다.'
    }
}

function Invoke-Aws([string[]]$Arguments) {
    $output = & aws @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "aws $($Arguments -join ' ') 실패: $($output | Out-String)"
    }
    return ($output | Out-String)
}

# 1. 장기 프로필이 있고 어느 사용자인지 확인한다. 이 호출에는 MFA 조건이 없다.
$missingProfile = $false
try {
    $identityJson = Invoke-Aws @('sts', 'get-caller-identity', '--profile', $LongTermProfile, '--output', 'json')
} catch {
    $missingProfile = $true
}
if ($missingProfile) {
    Write-Host ''
    Write-Host "'$LongTermProfile' 프로필이 없다. 액세스 키 입력은 사람이 직접 해야 하는 한 단계다:" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "    aws configure --profile $LongTermProfile" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  리전 $Region, 출력 형식 json. 끝나면 이 스크립트를 다시 실행하면 나머지는 자동이다." -ForegroundColor Yellow
    Write-Host ''
    exit 2
}
$identity = $identityJson | ConvertFrom-Json
if ($identity.Account -ne $ExpectedAccountId) {
    throw "계정이 $($identity.Account) 다. 기대값은 $ExpectedAccountId — 엉뚱한 계정에 작업하지 않도록 여기서 멈춘다."
}
$userName = ($identity.Arn -split '/')[-1]

# 2. MFA 기기를 찾는다. iam:ListMFADevices 는 자기 사용자에 대해 MFA 없이 허용된다
#    (developer-access.tf 의 EnrollAndViewOwnMfa).
#
#    기기가 없으면 그것으로 끝내지 않는다. 이 계정에는 Terraform 이 관리하는 다섯 사용자
#    (SeoDongWi, hjcud, hoyow, kcrmin, pjy) 밖에서 만들어진 사용자도 있고, 그런 사용자는
#    MFA 조건이 붙은 그룹 정책을 받지 않아 장기 자격증명만으로도 동작한다. 그래서 MFA 가
#    없으면 세션 승격을 건너뛰고 장기 자격증명을 그대로 대상 프로필에 복사한다 —
#    스크립트가 사용자마다 다르게 실패하지 않도록.
$devices = @()
try {
    $devicesJson = Invoke-Aws @('iam', 'list-mfa-devices', '--user-name', $userName, '--profile', $LongTermProfile, '--output', 'json')
    $devices = @(($devicesJson | ConvertFrom-Json).MFADevices)
} catch {
    $devices = @()
}

$usedMfa = $false
if ($devices.Count -gt 0) {
    $serial = $devices[0].SerialNumber
    if (-not $MfaCode) {
        $MfaCode = Read-Host "MFA 코드 6자리 ($serial)"
    }
    if ($MfaCode -notmatch '^\d{6}$') {
        throw 'MFA 코드는 숫자 6자리다.'
    }
    $sessionJson = Invoke-Aws @(
        'sts', 'get-session-token',
        '--profile', $LongTermProfile,
        '--serial-number', $serial,
        '--token-code', $MfaCode,
        '--duration-seconds', "$DurationSeconds",
        '--output', 'json'
    )
    $credentials = ($sessionJson | ConvertFrom-Json).Credentials
    $usedMfa = $true
} else {
    $serial = '(없음)'
    $credentials = $null
}

# 3. 대상 프로필에 심는다. 값은 출력하지 않는다 — get-session-token 의 출력을 그대로 보면
#    비밀값이 평문으로 노출되고, 그 화면을 어딘가에 복사하는 순간 12시간짜리라도 유출이다.
if ($usedMfa) {
    Invoke-Aws @('configure', 'set', 'aws_access_key_id', $credentials.AccessKeyId, '--profile', $TargetProfile) | Out-Null
    Invoke-Aws @('configure', 'set', 'aws_secret_access_key', $credentials.SecretAccessKey, '--profile', $TargetProfile) | Out-Null
    Invoke-Aws @('configure', 'set', 'aws_session_token', $credentials.SessionToken, '--profile', $TargetProfile) | Out-Null
} else {
    # 세션이 아니라 장기 자격증명을 그대로 쓴다. 이전 실행이 남긴 session token 이 있으면
    # 지운다 — 만료된 토큰이 남아 있으면 모든 호출이 조용히 거부된다.
    $sourceKey = (Invoke-Aws @('configure', 'get', 'aws_access_key_id', '--profile', $LongTermProfile)).Trim()
    $sourceSecret = (Invoke-Aws @('configure', 'get', 'aws_secret_access_key', '--profile', $LongTermProfile)).Trim()
    Invoke-Aws @('configure', 'set', 'aws_access_key_id', $sourceKey, '--profile', $TargetProfile) | Out-Null
    Invoke-Aws @('configure', 'set', 'aws_secret_access_key', $sourceSecret, '--profile', $TargetProfile) | Out-Null
    & aws configure set aws_session_token '' --profile $TargetProfile 2>&1 | Out-Null
}
Invoke-Aws @('configure', 'set', 'region', $Region, '--profile', $TargetProfile) | Out-Null
Invoke-Aws @('configure', 'set', 'output', 'json', '--profile', $TargetProfile) | Out-Null

# 4. 심은 프로필이 실제로 MFA 세션인지 확인한다. get-caller-identity 는 MFA 없이도
#    성공하므로 그것만으로는 증명이 안 된다. MFA 조건이 걸린 호출을 하나 시도해야 한다.
$verified = $false
$verifyDetail = ''
try {
    Invoke-Aws @('ec2', 'describe-instances', '--max-items', '1', '--profile', $TargetProfile, '--output', 'json') | Out-Null
    $verified = $true
} catch {
    $verifyDetail = ($_.Exception.Message -split "`n")[0]
}

$expiresAt = if ($usedMfa) {
    [DateTime]::Parse($credentials.Expiration).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
} else {
    '(만료 없음 — 장기 자격증명)'
}
([ordered]@{
    account        = $identity.Account
    user           = $userName
    session_kind   = if ($usedMfa) { 'mfa-session' } else { 'long-term (MFA 기기 없음)' }
    mfa_serial     = $serial
    target_profile = $TargetProfile
    expires_at_utc = $expiresAt
    hours          = if ($usedMfa) { [math]::Round($DurationSeconds / 3600.0, 1) } else { $null }
    access_verified = $verified
    verify_detail  = if ($verified) { 'ec2:DescribeInstances 통과 — MFA 조건이 걸린 호출이 성공했다' } else { "MFA 조건 호출 실패: $verifyDetail" }
    status         = if ($verified) { 'passed' } else { 'failed' }
}) | ConvertTo-Json -Compress

if (-not $verified) { exit 1 }
