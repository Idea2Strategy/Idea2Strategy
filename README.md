# Idea2Strategy

주식 전략·백테스트·가상 트레이딩 서비스입니다.

## 로컬 실행

준비물: Git, Docker Desktop, 팀 공용 백업 폴더

`local-development.env`는 로컬 Docker 전용 자격증명입니다. Git, 메신저, 이메일에 올리지 말고 팀 SSD로만 전달합니다(SSD 암호화 권장).

Windows PowerShell:

```powershell
git clone --recurse-submodules https://github.com/Idea2Strategy/Idea2Strategy.git
Set-Location Idea2Strategy
New-Item -ItemType Directory -Force .local-data | Out-Null
Copy-Item 'D:\Idea2Strategy-backups\baseline-2026-08-13' '.\.local-data\baseline-2026-08-13' -Recurse
.\scripts\init-local-env.ps1 -SharedEnvPath 'D:\Idea2Strategy-backups\local-development.env'
```

macOS:

```bash
git clone --recurse-submodules https://github.com/Idea2Strategy/Idea2Strategy.git
cd Idea2Strategy
mkdir -p .local-data
cp -R /Volumes/SSD/Idea2Strategy-backups/baseline-2026-08-13 .local-data/
cp /Volumes/SSD/Idea2Strategy-backups/local-development.env .env
chmod 600 .env
```

백업 위치가 다르면 복사 명령의 원본 경로만 수정합니다. `.env`는 아래 프로젝트 내부 경로를 사용합니다.

```dotenv
BACKUP_PATH=./.local-data/baseline-2026-08-13
```

이후에는 아래 명령만 실행합니다.

```powershell
docker compose up -d
```

최초 실행에만 PostgreSQL과 MinIO 데이터를 복원·검증합니다. 같은 백업으로 다시 실행하면 복원을 생략합니다. 백업 데이터는 Git에 포함하지 않습니다.

## 개발

수정한 서비스만 다시 빌드할 수 있습니다.

```powershell
docker compose up -d --build backend-api
docker compose up -d --build backtest-worker
```

로컬 데이터를 완전히 초기화하려면:

```powershell
docker compose down -v
docker compose up -d
```

`backend-batch`와 `market-gateway`는 기본 실행에서 제외되어 로컬 시장 데이터 수집을 실행하지 않습니다.
