# 개발 시작 가이드

## 준비

- Git
- Docker Desktop
- PowerShell 5.1 이상
- 각 하위 저장소 접근 권한

별도의 하네스, Stackcord, 담당자 선택, 관리자 승인, 작업 원장 초기화는 필요하지 않다.

## 저장소 준비

```powershell
git submodule update --init --recursive
git status --short --branch
```

기존 로컬 변경은 유지한다. 하위 모듈을 임의의 최신 커밋으로 당기지 말고 루트가 가리키는 커밋을 사용한다.

## 로컬 실행

```powershell
.\scripts\dev.ps1 up -Scope all -WithBackend -NoBrowser
.\scripts\dev.ps1 status
```

종료:

```powershell
.\scripts\dev.ps1 down
```

생성 파일과 임시 산출물은 Git이 무시하는 `.local/` 아래에 저장된다.

## 변경 원칙

- 제품 동작은 `specs/`, 서비스 간 의무는 `contracts/`, 데이터 모델은 `db/schema.dbml`을 기준으로 한다.
- 여러 저장소가 영향을 받으면 계약과 소비자를 함께 확인한다.
- 적용된 Flyway migration은 수정하지 않고 새 migration을 추가한다.
- 변경한 저장소의 build와 test를 실행한다.
- 관리자나 담당자 승인 절차는 없으며 브랜치와 PR 사용 여부는 작업 상황에 맞게 선택한다.
