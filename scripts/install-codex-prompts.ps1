<#
.SYNOPSIS
    추적되는 .agents/prompts 를 Codex 사용자 프롬프트로 설치한다.

.DESCRIPTION
    Codex CLI 는 $CODEX_HOME/prompts (기본 ~/.codex/prompts) 의 마크다운을 커스텀
    프롬프트로 읽어 /이름 으로 호출하게 해 준다. Claude 의 /start-work 에 해당하는
    것을 Codex 쪽에도 똑같이 주려면 그 디렉터리에 파일이 있어야 하는데, 사용자
    홈은 커밋할 수 없으므로 저장소에 원본(.agents/prompts)을 두고 이 스크립트가
    복사한다.

    같은 이름의 파일은 저장소 쪽이 정본이므로 덮어쓴다. Codex 를 안 쓰는 사람에게는
    복사된 파일이 아무 효과가 없으므로 항상 실행해도 무해하다. 멱등하다.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root '.agents/prompts'
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "추적되는 프롬프트 디렉터리가 없다: $source"
}

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$target = Join-Path $codexHome 'prompts'
if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
}

$installed = @()
foreach ($file in Get-ChildItem -LiteralPath $source -Filter '*.md' -File) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $target $file.Name) -Force
    $installed += $file.BaseName
}

([ordered]@{
    target    = $target
    installed = $installed
    usage     = ($installed | ForEach-Object { "/$_" })
    status    = 'passed'
}) | ConvertTo-Json -Compress
