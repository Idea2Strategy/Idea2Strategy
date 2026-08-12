[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$devScript = Join-Path $PSScriptRoot "dev.ps1"
$Host.UI.RawUI.WindowTitle = "Idea2Strategy Docker Development"

function Wait-ForMenu {
    Write-Host ""
    Read-Host "메뉴로 돌아가려면 Enter를 누르세요"
}

function Invoke-DevelopmentCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [ValidateSet("all", "front", "back")][string]$Scope = "all",
        [string]$Service = "all",
        [switch]$WithBackend,
        [switch]$NoBrowser,
        [switch]$Force
    )

    try {
        $arguments = @{
            Action = $Action
            Scope = $Scope
        }
        if ($WithBackend) {
            $arguments.WithBackend = $true
        }
        if ($Service -cne "all") {
            $arguments.Service = $Service
        }
        if ($NoBrowser) {
            $arguments.NoBrowser = $true
        }
        if ($Force) {
            $arguments.Force = $true
        }
        & $devScript @arguments
    }
    catch {
        Write-Host ""
        Write-Host "실행 실패: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-ManagementMenu {
    while ($true) {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host " Idea2Strategy Docker - 기타 관리"
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host " 1. 전체 상태 확인"
        Write-Host " 2. 전체 로그 보기 (종료: Ctrl+C)"
        Write-Host " 3. Frontend와 MinIO 브라우저 열기"
        Write-Host " 4. 전체 환경 다시 빌드·시작"
        Write-Host " 5. 전체 환경 종료 (데이터 유지)"
        Write-Host " 6. 전체 환경 초기화 (DB·MinIO 데이터 삭제)"
        Write-Host " 7. 변경한 서비스 하나만 다시 빌드·시작"
        Write-Host " 0. 이전 메뉴"
        Write-Host ""

        switch (Read-Host "선택") {
            "1" {
                Invoke-DevelopmentCommand -Action status -Scope all -NoBrowser
                Wait-ForMenu
            }
            "2" {
                Invoke-DevelopmentCommand -Action logs -Scope all -NoBrowser
                Wait-ForMenu
            }
            "3" {
                Invoke-DevelopmentCommand -Action open -Scope all
                Wait-ForMenu
            }
            "4" {
                Invoke-DevelopmentCommand -Action up -Scope all
                Wait-ForMenu
            }
            "5" {
                Invoke-DevelopmentCommand -Action down -Scope all -NoBrowser
                Wait-ForMenu
            }
            "6" {
                Write-Host ""
                Write-Host "PostgreSQL과 MinIO의 로컬 데이터가 모두 삭제됩니다." -ForegroundColor Yellow
                if ((Read-Host "계속하려면 RESET을 입력하세요") -ceq "RESET") {
                    Invoke-DevelopmentCommand -Action reset -Scope all -Force -NoBrowser
                }
                else {
                    Write-Host "초기화를 취소했습니다."
                }
                Wait-ForMenu
            }
            "7" {
                Write-Host ""
                Write-Host "선택 가능: frontend, backend-api, backend-batch, backend-worker, admin-mcp," -ForegroundColor Cyan
                Write-Host "           market-gateway, trading-worker, backtest-api, backtest-worker" -ForegroundColor Cyan
                $service = Read-Host "서비스 이름"
                Invoke-DevelopmentCommand -Action restart -Scope all -Service $service -NoBrowser
                Wait-ForMenu
            }
            "0" {
                return
            }
            default {
                Write-Host "올바른 번호를 선택하세요." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

while ($true) {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Idea2Strategy Docker 개발 환경"
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " 1. Frontend만 실행"
    Write-Host " 2. Backend 개발 인프라만 실행"
    Write-Host "    - PostgreSQL, Redis, MinIO, LocalStack SQS"
    Write-Host " 3. Frontend + Backend 개발 인프라 실행 (권장)"
    Write-Host " 4. API와 Worker 포함 전체 실행"
    Write-Host "    - Backend, Trading, Backtest 골격 빌드"
    Write-Host " 5. 기타 관리"
    Write-Host " 0. 종료"
    Write-Host ""

    switch (Read-Host "실행할 환경을 선택하세요") {
        "1" {
            Invoke-DevelopmentCommand -Action up -Scope front
            Wait-ForMenu
        }
        "2" {
            Invoke-DevelopmentCommand -Action up -Scope back
            Wait-ForMenu
        }
        "3" {
            Invoke-DevelopmentCommand -Action up -Scope all
            Wait-ForMenu
        }
        "4" {
            Invoke-DevelopmentCommand -Action up -Scope all -WithBackend
            Wait-ForMenu
        }
        "5" {
            Show-ManagementMenu
        }
        "0" {
            return
        }
        default {
            Write-Host "올바른 번호를 선택하세요." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
