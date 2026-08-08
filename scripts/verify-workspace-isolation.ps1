<#
.SYNOPSIS
    이 체크아웃을 가릴 수 있는 상위 디렉터리의 사본을 찾아낸다.

.DESCRIPTION
    2026-08-08 에 실제로 일어난 사고를 자동으로 잡기 위한 검사다. 이 저장소의 옛 클론이
    상위 디렉터리에 남아 있었고, 그 안의 `.claude/skills/start-work` 사본이 정본 스킬을
    가려서 `/start-work` 가 63커밋 전 절차로 동작했다. 같은 클론의 `CLAUDE.md` 는 이미
    활동하지 않는 담당자에게 작업을 배정하고 현재 계획서의 존재를 몰랐다.

    `git pull` 은 이것을 고칠 수 없다. 가리는 파일이 **다른 저장소** 소속이므로 git 이
    아예 보지 못한다. 낡은 지시를 조용히 읽는 것이 이 프로젝트가 실제로 망가진 방식이라,
    조용히 넘어가지 않고 여기서 멈춘다.

    오탐을 만들지 않도록 두 가지만 본다. 개인용 `~/CLAUDE.md` 나 이름이 겹치지 않는
    개인 스킬은 정상적인 사용법이므로 걸리지 않는다.

      1. 상위 디렉터리가 **이 저장소와 같은 origin** 을 가진 git 작업 트리다
         (= 이 프로젝트의 다른 클론이 이 체크아웃을 품고 있다).
      2. 상위 디렉터리의 `.claude/skills/<이름>` 이 이 저장소의 같은 이름 스킬과 충돌한다.

.PARAMETER Json
    기계가 읽을 형태로만 출력한다.

.EXAMPLE
    ./scripts/verify-workspace-isolation.ps1
#>
[CmdletBinding()]
param([switch]$Json)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot

function Get-OriginUrl([string]$Directory) {
    try {
        $url = & git -C $Directory config --get remote.origin.url 2>$null
        if ($LASTEXITCODE -ne 0) { return '' }
        return "$url".Trim()
    } catch { return '' }
}

function Test-WorkTree([string]$Directory) {
    try {
        $inside = & git -C $Directory rev-parse --is-inside-work-tree 2>$null
        return ($LASTEXITCODE -eq 0 -and "$inside".Trim() -eq 'true')
    } catch { return $false }
}

# 비교는 정규화한 뒤에 한다. 같은 저장소를 https 와 ssh 로, .git 접미사 유무로 적어도
# 같은 클론이다.
function Get-RepositoryIdentity([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return '' }
    $normalized = $Url.Trim().ToLowerInvariant()
    $normalized = $normalized -replace '\.git$', ''
    $normalized = $normalized -replace '^git@([^:]+):', 'https://$1/'
    $normalized = $normalized -replace '/+$', ''
    return $normalized
}

$rootIdentity = Get-RepositoryIdentity (Get-OriginUrl $root)
$repositorySkills = @()
$skillRoot = Join-Path $root '.claude/skills'
if (Test-Path -LiteralPath $skillRoot -PathType Container) {
    $repositorySkills = @(Get-ChildItem -LiteralPath $skillRoot -Directory | Select-Object -ExpandProperty Name)
}

$findings = @()
$ancestor = Split-Path -Parent $root
while ($ancestor -and (Test-Path -LiteralPath $ancestor -PathType Container)) {
    # 1. 이 프로젝트의 다른 클론이 우리를 품고 있는가
    if (Test-WorkTree $ancestor) {
        $ancestorIdentity = Get-RepositoryIdentity (Get-OriginUrl $ancestor)
        if ($ancestorIdentity -and $rootIdentity -and $ancestorIdentity -eq $rootIdentity) {
            $findings += [ordered]@{
                kind      = 'ancestor-clone'
                path      = $ancestor
                detail    = '이 저장소의 다른 클론이 상위 디렉터리에 있고 이 체크아웃을 품고 있다. 그 폴더에서 실행한 git 명령은 엉뚱한 저장소를 대상으로 하며, 그 폴더의 CLAUDE.md·AGENTS.md 가 정본을 가린다.'
                remedy    = "그 폴더에서 작업하지 않는다. 되살릴 이유가 없으면 git 메타데이터를 제거해 평범한 폴더로 만든다: Remove-Item -Recurse -Force '$ancestor\.git'"
            }
        }
    }

    # 2. 같은 이름의 스킬 사본이 위에 있는가
    $ancestorSkillRoot = Join-Path $ancestor '.claude/skills'
    if ($repositorySkills.Count -gt 0 -and (Test-Path -LiteralPath $ancestorSkillRoot -PathType Container)) {
        foreach ($name in @(Get-ChildItem -LiteralPath $ancestorSkillRoot -Directory | Select-Object -ExpandProperty Name)) {
            if ($repositorySkills -contains $name) {
                $findings += [ordered]@{
                    kind   = 'shadowed-skill'
                    path   = (Join-Path $ancestorSkillRoot $name)
                    detail = "스킬 '$name' 이 이 저장소와 상위 디렉터리 양쪽에 있다. 상위 사본이 로드되면 낡은 절차가 실행되고, git pull 은 그것을 갱신하지 못한다."
                    remedy = "상위 사본을 제거한다: Remove-Item -Recurse -Force '$(Join-Path $ancestorSkillRoot $name)'"
                }
            }
        }
    }

    $parent = Split-Path -Parent $ancestor
    if ($parent -eq $ancestor) { break }
    $ancestor = $parent
}

$result = [ordered]@{
    repository = $root
    origin     = $rootIdentity
    findings   = $findings
    status     = if ($findings.Count -eq 0) { 'passed' } else { 'failed' }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
    if ($findings.Count -gt 0) { exit 1 }
    exit 0
}

if ($findings.Count -eq 0) {
    ($result | ConvertTo-Json -Compress)
    exit 0
}

Write-Host ''
Write-Host '작업 공간 격리 검사 실패 — 상위 디렉터리의 사본이 이 체크아웃을 가리고 있다.' -ForegroundColor Red
Write-Host '이 상태로 시작하면 낡은 지시를 읽게 되고, git pull 로는 고쳐지지 않는다.' -ForegroundColor Red
foreach ($finding in $findings) {
    Write-Host ''
    Write-Host ("  [{0}] {1}" -f $finding.kind, $finding.path) -ForegroundColor Yellow
    Write-Host ("      {0}" -f $finding.detail)
    Write-Host ("      해결: {0}" -f $finding.remedy) -ForegroundColor Cyan
}
Write-Host ''
exit 1
