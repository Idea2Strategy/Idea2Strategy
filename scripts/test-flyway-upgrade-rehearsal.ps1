<#
.SYNOPSIS
    직전 릴리스 스키마 위에 현재 번들을 적용하는 리허설.

.DESCRIPTION
    scripts/test-flyway-ci-bundle.ps1 은 **빈** PostgreSQL 에 번들을 적용한다. 그것이
    증명하는 것은 새 설치이고, 릴리스가 실제로 하는 일은 새 설치가 아니다 — 이미 스키마가
    있는 데이터베이스에 새 마이그레이션만 얹는다.

    두 경로는 갈릴 수 있다. 이미 적용된 마이그레이션 파일이 나중에 수정되면 체크섬이 어긋나고,
    빈 테이블을 가정한 마이그레이션은 행이 있으면 실패하고, 멱등하지 않은 seed 는 두 번째
    적용에서 중복을 만든다. 빈 DB 시험은 세 경우 모두 통과한다.

    이 스크립트는 그 차이를 시험한다.

      1. -FromRef 의 db/flyway-ci-bundle 을 꺼내 빈 PostgreSQL 에 적용한다(= 직전 릴리스).
      2. 같은 데이터베이스에 현재 번들을 적용한다(= 업그레이드).
      3. validate, 그리고 한 번 더 migrate 해서 pending 이 없는지 본다.
      4. 최종 상태가 **새 설치와 같은지** 비교한다 — 테이블 수와 성공 마이그레이션 수.

    4번이 이 시험의 핵심이다. 업그레이드 결과가 새 설치와 같은 상태라면 두 경로가 수렴한다는
    뜻이고, 그것이 릴리스가 필요로 하는 보장이다. 숫자는 인자로 받지 않고
    test-flyway-ci-bundle.ps1 과 같은 값을 여기에 두 곳이 아닌 한 곳에서 읽도록
    -ExpectedTables / -ExpectedMigrations 기본값으로 고정한다.

    적용된 마이그레이션은 불변이므로 이 시험은 되돌리기를 다루지 않는다. 되돌리기는 스키마
    되돌리기가 아니라 스냅샷 복원이며 docs/database-rollback-procedure.md 에 있다.

.PARAMETER FromRef
    직전 릴리스로 볼 git ref. 생략하면 번들 내용이 현재와 다른 가장 가까운 조상을 자동으로
    찾는다 — 델타가 0 인 리허설은 아무것도 증명하지 않으므로 그것을 피한다.

.PARAMETER ExpectedTables
    업그레이드 후 기대하는 application 테이블 수. 새 설치와 같아야 한다.

.PARAMETER ExpectedMigrations
    업그레이드 후 기대하는 성공 마이그레이션 수. 새 설치와 같아야 한다.

.EXAMPLE
    .\scripts\test-flyway-upgrade-rehearsal.ps1
    .\scripts\test-flyway-upgrade-rehearsal.ps1 -FromRef fcede15
#>
[CmdletBinding()]
param(
    [string]$FromRef,
    [int]$ExpectedTables = 180,
    [int]$ExpectedMigrations = 53
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$currentBundle = Join-Path $root 'db/flyway-ci-bundle'
if (-not (Test-Path -LiteralPath $currentBundle -PathType Container)) {
    throw "현재 번들이 없다: $currentBundle"
}

function Get-BundleTreeHash([string]$Ref) {
    $out = & git -C $root rev-parse "${Ref}:db/flyway-ci-bundle" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($out | Out-String).Trim()
}

# 번들 트리 해시가 다른 가장 가까운 조상을 찾는다. source-revisions.json 만 달라진 커밋도
# 트리 해시가 다르지만, 그런 커밋은 마이그레이션 델타가 0 이라 리허설이 공허하다. 그래서
# .sql 목록이 실제로 다른 커밋까지 내려간다.
function Get-CurrentSqlNames {
    return (Get-ChildItem -LiteralPath $currentBundle -Filter 'V*.sql' |
        Sort-Object -Property Name -CaseSensitive |
        Select-Object -ExpandProperty Name) -join "`n"
}

function Get-SqlNamesAt([string]$Ref) {
    $out = & git -C $root ls-tree -r --name-only $Ref -- db/flyway-ci-bundle 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($out | Where-Object { $_ -match '/V[^/]+\.sql$' } |
        ForEach-Object { Split-Path -Leaf $_ } |
        Sort-Object -CaseSensitive) -join "`n")
}

$currentSql = Get-CurrentSqlNames
if (-not $FromRef) {
    # 자동으로 "번들이 다른 가장 가까운 조상" 을 고르지 않는다. 그렇게 고르면 개발 중간
    # 상태가 잡히고, 개발 중간 상태와 현재 사이에는 아직 적용되지 않은 마이그레이션을 고친
    # 흔적이 정상적으로 존재한다. 그것을 릴리스 경계로 착각하면 이 시험은 정당한 편집을
    # 결함으로 신고한다.
    #
    # 직전 릴리스는 **마지막으로 적용된 부트스트랩의 번들 상태**다. 그 값은 저장소가 아니라
    # AWS 수령증이 알고 있으므로 사람이 지정한다.
    throw (
        "-FromRef 가 필요하다. 직전 릴리스로 쓸 커밋을 명시한다.`n`n" +
        "직전 릴리스는 '번들이 다른 가장 가까운 조상' 이 아니다. 그것은 개발 중간 상태이고, " +
        "그 사이에는 아직 적용되지 않은 마이그레이션을 고친 정당한 흔적이 있다. 마지막으로 " +
        "적용된 부트스트랩의 루트 커밋을 쓴다 — AWS 수령증의 root_sha 이며 " +
        "docs/evidence/INT02-aws.md 에 기록되어 있다.`n`n" +
        "그 커밋의 마이그레이션 집합이 현재와 같으면 아직 리허설할 델타가 없다는 뜻이고, " +
        '이 스크립트는 그 경우도 거부한다 — 델타 0 리허설은 아무것도 증명하지 않는다.')
}

$fromTree = Get-BundleTreeHash $FromRef
if (-not $fromTree) { throw "ref 에서 번들을 읽지 못했다: $FromRef" }
$fromSql = Get-SqlNamesAt $FromRef
if ($fromSql -ceq $currentSql) {
    throw ("$FromRef 의 마이그레이션 집합이 현재와 같다. 델타 0 리허설은 업그레이드 경로를 " +
        '증명하지 않으므로 거부한다.')
}

$fromCount = @($fromSql -split "`n" | Where-Object { $_ }).Count
$currentCount = @($currentSql -split "`n" | Where-Object { $_ }).Count
$addedNames = @(Compare-Object -ReferenceObject ($fromSql -split "`n") `
    -DifferenceObject ($currentSql -split "`n") -CaseSensitive |
    Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject)
$removedNames = @(Compare-Object -ReferenceObject ($fromSql -split "`n") `
    -DifferenceObject ($currentSql -split "`n") -CaseSensitive |
    Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject)

# 사라진 마이그레이션이 있으면 업그레이드가 성립하지 않는다. Flyway 는 적용되었으나 로컬에
# 없는 마이그레이션을 validate 에서 잡아내지만, 그 전에 여기서 이유를 분명히 말해 준다.
if ($removedNames.Count -gt 0) {
    throw ("$FromRef 에 있고 현재 번들에 없는 마이그레이션이 있다: " +
        ($removedNames -join ', ') +
        '. 적용된 마이그레이션은 불변이므로 업그레이드 경로가 성립하지 않는다.')
}

# 같은 이름인데 내용이 다른 마이그레이션을 먼저 잡는다. 그대로 두면 Flyway 가 체크섬
# 불일치로 멈추는데, 그 메시지는 "Migrations have failed validation" 한 줄이라 어느 파일이
# 문제인지 알려주지 않는다. 여기서 이름을 대는 편이 훨씬 빠르다.
function Get-BundleBlobMap([string]$Ref) {
    $map = @{}
    $lines = & git -C $root ls-tree -r $Ref -- db/flyway-ci-bundle 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    foreach ($line in $lines) {
        if ($line -match '^\S+\s+blob\s+(\S+)\s+(.+)$') {
            # blob sha 를 먼저 꺼내 둔다. 다음 -match 가 $Matches 를 덮어쓰므로, 나중에
            # $Matches[1] 을 읽으면 안쪽 정규식의 캡처('V' 또는 'R')가 나온다. 그렇게 되면
            # 모든 항목의 값이 같아져 이 검사가 어떤 변경도 찾지 못한다.
            $blob = $Matches[1]
            $path = $Matches[2]
            if ($path -match '/(V|R)[^/]+\.sql$') { $map[(Split-Path -Leaf $path)] = $blob }
        }
    }
    return $map
}

$fromBlobs = Get-BundleBlobMap $FromRef

# 현재 쪽은 HEAD 가 아니라 **작업트리** 를 센다. Flyway 에 마운트되는 것이 작업트리이므로,
# HEAD 와 비교하면 아직 커밋하지 않은 번들 갱신을 놓친다. git hash-object 를 쓰면 blob sha
# 와 같은 공간에서 비교된다.
function Get-WorkTreeBlobMap {
    $map = @{}
    foreach ($file in (Get-ChildItem -LiteralPath $currentBundle -File |
            Where-Object { $_.Name -match '^(V|R).+\.sql$' })) {
        $sha = (& git -C $root hash-object -- $file.FullName)
        if ($LASTEXITCODE -ne 0) { return $null }
        $map[$file.Name] = ($sha | Out-String).Trim()
    }
    return $map
}
$headBlobs = Get-WorkTreeBlobMap
$changedNames = @()
if ($null -ne $fromBlobs -and $null -ne $headBlobs) {
    foreach ($name in $fromBlobs.Keys) {
        if ($headBlobs.ContainsKey($name) -and $headBlobs[$name] -cne $fromBlobs[$name]) {
            $changedNames += $name
        }
    }
    $changedNames = @($changedNames | Sort-Object -CaseSensitive)
}

if ($changedNames.Count -gt 0) {
    throw (
        "$FromRef 와 현재 번들에 같은 이름으로 있으면서 내용이 다른 마이그레이션이 있다: " +
        ($changedNames -join ', ') + "`n`n" +
        "가능성은 둘이고, 판정이 완전히 다르다.`n" +
        "  (1) $FromRef 가 릴리스 경계가 아니다. 아직 어디에도 적용되지 않은 마이그레이션을 " +
        "고친 것이므로 정당하다. 이 스크립트는 '직전 릴리스' 를 기준으로 삼아야 하므로 " +
        "-FromRef 를 실제로 적용된 상태로 바꾼다.`n" +
        "  (2) 이미 적용된 마이그레이션이 나중에 수정되었다. 이것은 결함이며 배포를 멈춰야 " +
        "한다.`n`n" +
        "구분하는 방법: 그 파일을 수정한 커밋을 찾고, 그 커밋이 마지막으로 적용된 부트스트랩의 " +
        "루트 커밋의 조상인지 본다.`n" +
        "  git log --oneline -- db/flyway-ci-bundle/<파일>`n" +
        "  git merge-base --is-ancestor <수정커밋> <적용된-루트-SHA>`n" +
        "조상이면 (1) 이고, 아니면 (2) 다. 적용된 루트 SHA 는 AWS 부트스트랩 수령증의 " +
        'root_sha 이며 docs/evidence/INT02-aws.md 에 기록되어 있다.')
}

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$container = "idea2strategy-upgrade-rehearsal-$suffix"
$database = 'idea2strategy'
$user = 'idea2strategy'
$password = "rehearsal-$suffix"
$previousRoot = Join-Path ([System.IO.Path]::GetTempPath()) "i2s-prev-bundle-$suffix"
$previousBundle = $null

function Invoke-FlywayAgainst([string]$BundlePath, [string]$Command, [switch]$Json) {
    $arguments = @(
        'run', '--rm',
        '--network', "container:$container",
        '-v', "${BundlePath}:/flyway/sql:ro",
        'redgate/flyway:11-alpine',
        "-url=jdbc:postgresql://localhost:5432/$database",
        "-user=$user",
        "-password=$password",
        '-connectRetries=30'
    )
    if ($Json) { $arguments += '-outputType=json' }
    $arguments += $Command
    $output = & docker @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Flyway 의 메시지가 곧 진단이다. 그것을 삼키면 "validate 가 실패했다" 라는, 아무
        # 도움이 안 되는 문장만 남는다.
        ($output | Out-String) | Out-Host
        throw "Flyway $Command 가 실패했다 ($BundlePath). 위 출력이 이유다."
    }
    return $output
}

function Get-Scalar([string]$Sql) {
    $value = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc $Sql)
    if ($LASTEXITCODE -ne 0) { throw "조회에 실패했다: $Sql" }
    return ($value | Out-String).Trim()
}

$schemaList = "'identity','strategy','bot','storage','market_data','trading','backtest'," +
    "'performance','competition','operations'"
$tableCountSql = "SELECT count(*) FROM information_schema.tables " +
    "WHERE table_schema IN ($schemaList) AND table_type = 'BASE TABLE';"
$successSql = 'SELECT count(*) FROM flyway_schema_history WHERE success;'

try {
    # 직전 릴리스 번들을 작업 트리와 무관하게 꺼낸다. checkout 을 쓰지 않는 이유는 이
    # 스크립트가 다른 세션과 체크아웃을 공유할 수 있기 때문이다.
    # zip 을 쓰는 이유: PATH 의 tar 가 Git 배포판의 것이면 `-C C:\...` 의 `C:` 를 원격
    # 호스트로 해석해 실패한다. Expand-Archive 는 PowerShell 5.1 에 있고 그 문제가 없다.
    New-Item -ItemType Directory -Path $previousRoot -Force | Out-Null
    $archive = Join-Path ([System.IO.Path]::GetTempPath()) "i2s-prev-bundle-$suffix.zip"
    & git -C $root archive --format=zip --output=$archive $FromRef 'db/flyway-ci-bundle'
    if ($LASTEXITCODE -ne 0) { throw "번들을 꺼내지 못했다: $FromRef" }
    Expand-Archive -LiteralPath $archive -DestinationPath $previousRoot -Force
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    $previousBundle = Join-Path $previousRoot 'db/flyway-ci-bundle'
    if (-not (Test-Path -LiteralPath $previousBundle -PathType Container)) {
        throw "꺼낸 아카이브에 db/flyway-ci-bundle 이 없다: $FromRef"
    }

    $started = docker run -d `
        --name $container `
        --health-cmd "pg_isready -U $user -d $database" `
        --health-interval 2s `
        --health-timeout 2s `
        --health-retries 30 `
        -e "POSTGRES_DB=$database" `
        -e "POSTGRES_USER=$user" `
        -e "POSTGRES_PASSWORD=$password" `
        postgres:16-alpine
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($started)) {
        throw '임시 PostgreSQL 컨테이너를 띄우지 못했다.'
    }

    $healthy = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        $health = (docker inspect --format '{{.State.Health.Status}}' $container 2>$null).Trim()
        if ($health -eq 'healthy') { $healthy = $true; break }
        if ($health -eq 'unhealthy') { throw '임시 PostgreSQL 이 unhealthy 가 되었다.' }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) { throw '임시 PostgreSQL 을 기다리다 시간이 초과됐다.' }

    # 1단계 — 직전 릴리스 스키마.
    Invoke-FlywayAgainst $previousBundle 'migrate' | Out-Host
    $previousTables = [int](Get-Scalar $tableCountSql)
    $previousMigrations = [int](Get-Scalar $successSql)
    if ($previousMigrations -lt 1) {
        throw '직전 릴리스 번들이 마이그레이션을 하나도 적용하지 못했다.'
    }

    # 2단계 — 업그레이드. validate 를 먼저 돌려, 이미 적용된 파일이 그 사이 수정되었는지
    # 부터 잡는다. 체크섬 불일치는 migrate 에서도 잡히지만 validate 가 더 분명히 말한다.
    Invoke-FlywayAgainst $currentBundle 'validate' | Out-Host
    Invoke-FlywayAgainst $currentBundle 'migrate' | Out-Host
    $upgradedTables = [int](Get-Scalar $tableCountSql)
    $upgradedMigrations = [int](Get-Scalar $successSql)

    # 3단계 — 두 번째 migrate 가 아무것도 하지 않아야 한다.
    Invoke-FlywayAgainst $currentBundle 'migrate' | Out-Host
    $afterSecond = [int](Get-Scalar $successSql)
    if ($afterSecond -ne $upgradedMigrations) {
        throw "업그레이드 뒤 두 번째 migrate 가 마이그레이션을 더 적용했다: $upgradedMigrations -> $afterSecond."
    }
    $info = (Invoke-FlywayAgainst $currentBundle 'info' -Json) -join "`n"
    if ($info -match '(?i)"state"\s*:\s*"pending"') {
        throw '업그레이드 뒤에도 Flyway 가 pending 마이그레이션을 보고한다.'
    }

    # 4단계 — 새 설치와 같은 상태인가.
    if ($upgradedTables -ne $ExpectedTables) {
        throw ("업그레이드 후 테이블이 $upgradedTables 개다. 새 설치와 같은 " +
            "$ExpectedTables 개여야 한다 — 두 경로가 수렴하지 않는다.")
    }
    if ($upgradedMigrations -ne $ExpectedMigrations) {
        throw ("업그레이드 후 성공 마이그레이션이 $upgradedMigrations 개다. 새 설치와 같은 " +
            "$ExpectedMigrations 개여야 한다.")
    }

    $failed = [int](Get-Scalar 'SELECT count(*) FROM flyway_schema_history WHERE NOT success;')
    if ($failed -ne 0) { throw "flyway_schema_history 에 실패한 항목이 $failed 개 있다." }

    ([ordered]@{
        status                = 'passed'
        from_ref              = (& git -C $root rev-parse --short $FromRef).Trim()
        from_subject          = (& git -C $root log --format=%s -1 $FromRef).Trim()
        previous_sql_files    = $fromCount
        current_sql_files     = $currentCount
        added_migrations      = $addedNames
        previous_tables       = $previousTables
        previous_migrations   = $previousMigrations
        upgraded_tables       = $upgradedTables
        upgraded_migrations   = $upgradedMigrations
        second_run_pending    = 0
        converges_with_fresh_install = $true
        postgres              = '16-alpine'
        flyway                = '11-alpine'
    }) | ConvertTo-Json -Compress -Depth 4
}
finally {
    docker rm -f $container 2>$null | Out-Null
    Remove-Item -LiteralPath $previousRoot -Recurse -Force -ErrorAction SilentlyContinue
}
